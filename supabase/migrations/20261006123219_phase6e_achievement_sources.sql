-- Shared exact-scope authorization. Role capability is never sufficient alone.
create function boss_private.achievement_platform_manager(actor uuid)returns boolean language plpgsql volatile security definer set search_path=''as $$begin
 perform 1 from public.role_assignments where person_id=actor order by id for share;
 perform boss_private.games_require_live_auth();
 return exists(select 1 from public.people p join public.role_assignments a on a.person_id=p.id join public.roles r on r.id=a.role_id and r.status='active'join public.role_permissions rp on rp.role_id=r.id join public.permissions permission on permission.id=rp.permission_id and permission.key='achievement_definitions.manage'and permission.status='active'where p.id=actor and p.status='active'and a.status='active'and a.scope_type='platform'and a.organization_id is null and a.scope_id is null and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()));
end$$;
revoke all on function boss_private.achievement_platform_manager(uuid)from public,anon,authenticated,service_role;
create function boss_private.achievement_permission(actor uuid,k text,org uuid,team uuid default null)returns boolean language sql volatile security definer set search_path=''as $$
 select k=any(array['achievement_definitions.manage','awards.issue','awards.approve'])
 and exists(select 1 from public.people where id=actor and status='active')
 and exists(select 1 from public.organizations where id=org and status='active')and boss_private.games_module_live(org,'sports')
 and(team is null or exists(select 1 from public.teams where id=team and organization_id=org and status='active'))
 and exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.key=k and p.status='active'
 where a.person_id=actor and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and(
  a.scope_type='platform'and a.scope_id is null and a.organization_id is null
  or a.organization_id=org and(
   a.scope_type='organization'and a.scope_id=org and exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
   or a.scope_type='organization_unit'and team is not null and a.scope_id=(select parent_unit_id from public.teams where id=team and organization_id=org)and exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
   or a.scope_type='team'and team is not null and a.scope_id=team and exists(select 1 from public.team_memberships m where m.organization_id=org and m.team_id=team and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())))))
$$;
create function boss_private.achievement_lock_authority(actor uuid,org uuid,team uuid default null,profile uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$begin
 perform 1 from public.role_assignments where person_id=actor order by id for share;
 perform 1 from public.organization_memberships where organization_id=org and person_id=actor order by id for share;
 perform 1 from public.team_memberships where organization_id=org and(person_id=actor or participant_id=(select participant_id from public.athlete_profiles where id=profile))order by id for share;
 perform 1 from public.organization_modules where organization_id=org order by id for share;
 perform boss_private.games_require_live_auth();
end$$;

create function boss_private.achievement_stat_pending(rev public.achievement_definition_revisions,org uuid)returns boolean language sql stable security definer set search_path=''as $$
 select exists(select 1 from public.stat_game_selections gs join public.games g on g.id=gs.game_id where gs.generation<>gs.refreshed_generation and g.organization_id=org and g.sport_key=rev.sport_key and(rev.team_id is null or rev.team_id in(g.primary_team_id,g.opponent_team_id))and(rev.season_id is null or g.season_id=rev.season_id))or exists(select 1 from public.stat_origin_summaries s where s.organization_id=org and s.sport_key=rev.sport_key and(rev.team_id is null or s.team_id=rev.team_id)and(rev.season_id is null or s.season_id=rev.season_id)and not s.is_current)
$$;
revoke all on function boss_private.achievement_stat_pending(public.achievement_definition_revisions,uuid)from public,anon,authenticated,service_role;

-- Facts are bounded materialized-source references. No arbitrary expression or raw-play scan.
create function boss_private.achievement_facts(rev public.achievement_definition_revisions,org uuid,p_after text default null,p_limit integer default 50,p_subject text default null,p_context text default null)returns setof jsonb language plpgsql stable security definer set search_path=''as $$
declare x record;payload jsonb;manifest jsonb;valid boolean;co boolean;holder boolean;state text;source uuid;gen bigint;achieved timestamptz;subject text;ctx text;rk text;begin
 if p_limit not between 1 and 51 then raise exception'Invalid achievement batch'using errcode='PT422';end if;
 if rev.source_kind in('athlete_season','athlete_career','team_season')then
  for x in
   with keys as(select distinct ss.person_id,ss.team_id,case when rev.source_kind='athlete_career'then null::uuid else ss.season_id end season_id,
    coalesce(ss.person_id::text,ss.team_id::text)||':'||case when rev.source_kind='athlete_career'then'career'else coalesce(ss.season_id::text,'unassigned')||':'||ss.team_id::text end rk
    from public.stat_origin_summaries ss where ss.organization_id=org and ss.sport_key=rev.sport_key and(rev.team_id is null or ss.team_id=rev.team_id)and(rev.season_id is null or ss.season_id=rev.season_id)and((rev.subject_type='athlete')=(ss.person_id is not null)))
   select distinct on(k.rk) k.*,ap.id profile_id from keys k left join public.athlete_profiles ap on ap.person_id=k.person_id and ap.status='active'
   where(p_after is null or k.rk>p_after)and(p_subject is null or coalesce(k.person_id::text,k.team_id::text)=p_subject)and(p_context is null or case when rev.source_kind='athlete_career'then'career'else coalesce(k.season_id::text,'unassigned')||':'||k.team_id::text end=p_context)and(rev.subject_type<>'athlete'or ap.id is not null)order by k.rk limit p_limit
  loop
   select coalesce(jsonb_agg(ss.summary order by ss.id),'[]'),jsonb_build_object('sources',coalesce(jsonb_agg(jsonb_build_object('id',ss.id,'generation',ss.generation,'watermark',ss.source_watermark,'team_id',ss.team_id,'season_id',ss.season_id)order by ss.id),'[]')),bool_and(ss.is_current),min(ss.id::text)::uuid,max(ss.generation),max(ss.refreshed_at)
   into payload,manifest,valid,source,gen,achieved from public.stat_origin_summaries ss
   where ss.organization_id=org and ss.sport_key=rev.sport_key and ss.person_id is not distinct from x.person_id
    and(rev.team_id is null or ss.team_id=rev.team_id)and(rev.season_id is null or ss.season_id=rev.season_id)
    and(rev.source_kind='athlete_career'or(ss.team_id=x.team_id and ss.season_id is not distinct from x.season_id));
   if jsonb_array_length(payload)>128 then raise exception'Achievement origin bound exceeded'using errcode='PT422';end if;
   payload:=boss_private.stat_compose(payload);valid:=coalesce(valid,false)and(payload->'metrics'->rev.metric_key->>'complete_value')is not null
    and coalesce((payload->'metrics'->rev.metric_key->>'partial_games')::int,0)=0 and coalesce((payload->'metrics'->rev.metric_key->>'legacy_unknown_games')::int,0)=0 and coalesce((payload->'metrics'->rev.metric_key->>'untracked_games')::int,0)=0
    and(payload->'metrics'->rev.metric_key->>'complete_value')::numeric>=rev.threshold;
   if valid then
    select min(crossing.scheduled_start_at)into achieved from(
     select g.scheduled_start_at,case when rev.metric_key like'long_%'then max((c.components->>rev.metric_key)::numeric)over(order by g.scheduled_start_at,g.id)else sum((c.components->>rev.metric_key)::numeric)over(order by g.scheduled_start_at,g.id)end value
     from public.stat_game_contributions c join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id join public.games g on g.id=c.game_id and g.status='final'and g.finalization_count=c.epoch
     where c.organization_id=org and c.sport_key=rev.sport_key and c.person_id is not distinct from x.person_id and c.classification='official'and(rev.team_id is null or c.team_id=rev.team_id)and(rev.season_id is null or c.season_id=rev.season_id)and(rev.source_kind='athlete_career'or(c.team_id=x.team_id and c.season_id is not distinct from x.season_id))
    )crossing where crossing.value>=rev.threshold;
   end if;
   return next jsonb_build_object('key',x.rk,'subject_key',coalesce(x.person_id::text,x.team_id::text),'profile_id',x.profile_id,'person_id',x.person_id,'team_id',case when rev.source_kind='athlete_career'then rev.team_id else x.team_id end,'season_id',x.season_id,'context_key',case when rev.source_kind='athlete_career'then'career'else coalesce(x.season_id::text,'unassigned')||':'||x.team_id::text end,'source_type','stat_summary','source_id',source,'source_generation',gen,'source_manifest',manifest,'source_hash',md5(manifest::text),'state',case when valid then'current'else'corrected'end,'achieved_at',achieved,'qualifies',valid,'holder',false,'co_holder',false);
  end loop;
 elsif rev.source_kind='athlete_game'then
  for x in select c.*,ap.id profile_id,g.scheduled_start_at,gs.generation source_generation from public.stat_game_contributions c join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id join public.games g on g.id=c.game_id and g.status='final'and g.finalization_count=c.epoch join public.athlete_profiles ap on ap.person_id=c.person_id and ap.participant_id=c.participant_id and ap.status='active'
   where c.organization_id=org and(p_subject is null or c.person_id::text=p_subject)and(p_context is null or c.game_id::text=p_context)and c.sport_key=rev.sport_key and c.classification='official'and(rev.team_id is null or c.team_id=rev.team_id)and(rev.season_id is null or c.season_id=rev.season_id)and(p_after is null or c.person_id::text||':'||c.game_id::text>p_after)order by c.person_id::text||':'||c.game_id::text limit p_limit
  loop
   valid:=x.coverage->>rev.metric_key='tracked'and(x.components->>rev.metric_key)::numeric>=rev.threshold;
   manifest:=jsonb_build_object('game_id',x.game_id,'finalization_id',x.finalization_id,'epoch',x.epoch,'generation',x.source_generation,'contribution_id',x.id,'participant_id',x.participant_id);
   return next jsonb_build_object('key',x.person_id::text||':'||x.game_id::text,'subject_key',x.person_id::text,'profile_id',x.profile_id,'person_id',x.person_id,'team_id',x.team_id,'season_id',x.season_id,'context_key',x.game_id::text,'source_type','stat_game','source_id',x.id,'source_generation',x.source_generation,'source_manifest',manifest,'source_hash',md5(manifest::text),'state',case when valid then'current'else'corrected'end,'achieved_at',x.scheduled_start_at,'qualifies',coalesce(valid,false),'holder',false,'co_holder',false);
  end loop;
 elsif rev.source_kind in('record','leaderboard')then
  for x in select rc.*,rs.state scope_state,rs.valid_until,rs.published_generation,rs.target_generation,rd.season_id,rd.team_id origin_team_id,rd.metric_kind
   from public.ranking_candidates rc join public.ranking_scopes rs on rs.id=rc.scope_id join public.ranking_definitions rd on rd.id=rs.definition_id
   where rd.id=rev.ranking_definition_id and(p_subject is null or coalesce(rc.person_id::text,rc.team_id::text)=p_subject)and(p_context is null or rc.scope_id::text=p_context)and rd.source_organization_id=org and(p_after is null or rc.subject_key||':'||rc.scope_id::text>p_after)order by rc.subject_key||':'||rc.scope_id::text limit p_limit
  loop
   valid:=x.scope_state='current'and x.published_generation=x.target_generation and(x.valid_until is null or x.valid_until>clock_timestamp())and x.built_generation=x.published_generation and x.qualification_state='qualified'and(x.metric_kind<>'rate'or((x.coverage->>'source_games')::int>0 and(x.coverage->>'complete_games')::int=(x.coverage->>'source_games')::int))and x.rank<=coalesce(rev.placement,1);
   source:=x.id;gen:=x.published_generation;manifest:=jsonb_build_object('candidate_id',x.id,'scope_id',x.scope_id,'generation',x.built_generation,'source_manifest',x.source_manifest);achieved:=x.achieved_at;holder:=false;co:=false;state:=case when valid then'current'else'historical'end;
   if rev.source_kind='record'then
    select e.id,e.achieved_at,e.generation,e.source_manifest into source,achieved,gen,manifest from public.record_events e where e.scope_id=x.scope_id and e.subject_key=x.subject_key and e.event_type in('recognized','co_holder_added','restored')order by e.recognized_at desc,e.id desc limit 1;
    if source is null then continue;end if;
    holder:=exists(select 1 from public.record_current_holders h where h.scope_id=x.scope_id and h.subject_key=x.subject_key);
    co:=holder and(select count(*)from public.record_current_holders h where h.scope_id=x.scope_id)>1;
    state:=case when exists(select 1 from public.record_events e where e.previous_event_id=source and e.event_type='invalidated_by_source_correction')then'corrected'when holder then'current'else'historical'end;
    valid:=state<>'corrected';manifest:=jsonb_build_object('record_event_id',source,'scope_id',x.scope_id,'generation',x.published_generation,'sources',manifest,'holder',holder,'co_holder',co);
   end if;
   return next jsonb_build_object('key',x.subject_key||':'||x.scope_id::text,'subject_key',coalesce(x.person_id::text,x.team_id::text),'profile_id',(select id from public.athlete_profiles where person_id=x.person_id and status='active'),'person_id',x.person_id,'team_id',coalesce(x.origin_team_id,x.team_id),'season_id',x.season_id,'context_key',x.scope_id::text,'source_type',case when rev.source_kind='record'then'record_event'else'ranking_candidate'end,'source_id',source,'source_generation',gen,'source_manifest',manifest,'source_hash',md5(manifest::text),'state',state,'achieved_at',achieved,'qualifies',coalesce(valid,false),'holder',holder,'co_holder',co);
  end loop;
 elsif rev.source_kind='tournament'then
  for x in select b.*,e.sport_key,e.season_id from public.tournament_brackets b join public.competition_editions e on e.id=b.edition_id where b.id=rev.bracket_id and e.organization_id=org and b.status in('complete','archived')loop
   select a.*into x from public.tournament_advancements a join public.tournament_matches m on m.id=a.source_match_id join public.tournament_stages s on s.id=m.stage_id where a.bracket_id=rev.bracket_id and s.stage_type=case when rev.placement=3 then'third_place'else'championship'end and m.revision_id=(select id from public.tournament_bracket_revisions where bracket_id=rev.bracket_id order by revision desc limit 1)order by a.generation desc,a.id desc limit 1;
   if x.id is null or x.advancement_kind='reversal'then return;end if;
   source:=x.id;gen:=x.generation;achieved:=x.created_at;
   select ce.team_id into source from public.competition_entries ce where ce.id=case when rev.placement=2 then x.loser_entry_id else x.winner_entry_id end and ce.team_organization_id=org;
   if source is null then return;end if;
   manifest:=jsonb_build_object('bracket_id',rev.bracket_id,'revision_id',x.revision_id,'advancement_id',x.id,'generation',x.generation,'entry_id',case when rev.placement=2 then x.loser_entry_id else x.winner_entry_id end,'placement',rev.placement);
   if rev.subject_type='team'then
    subject:=source::text;ctx:=rev.bracket_id::text;rk:=subject||':'||ctx;
    if(p_after is null or rk>p_after)and(p_subject is null or subject=p_subject)and(p_context is null or ctx=p_context)then return next jsonb_build_object('key',rk,'subject_key',subject,'team_id',source,'season_id',(select season_id from public.competition_editions where id=x.edition_id),'context_key',ctx,'source_type','tournament_bracket','source_id',rev.bracket_id,'source_generation',gen,'source_manifest',manifest,'source_hash',md5(manifest::text),'state','current','achieved_at',achieved,'qualifies',true,'holder',false,'co_holder',false);end if;
   else
    for x in select distinct ap.id profile_id,ap.person_id,ap.participant_id,ce.season_id from public.athlete_profiles ap join public.stat_game_contributions c on c.person_id=ap.person_id and c.participant_id=ap.participant_id and c.team_id=source and c.classification='official'and(c.participation->>'confirmed')::boolean join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id join public.tournament_matches m on m.game_id=c.game_id and m.bracket_id=rev.bracket_id join public.competition_editions ce on ce.id=m.edition_id where ap.status='active'and(p_subject is null or ap.person_id::text=p_subject)and(p_context is null or rev.bracket_id::text=p_context)and(p_after is null or ap.person_id::text||':'||rev.bracket_id::text>p_after)order by ap.person_id limit p_limit loop
     return next jsonb_build_object('key',x.person_id::text||':'||rev.bracket_id::text,'subject_key',x.person_id::text,'profile_id',x.profile_id,'person_id',x.person_id,'team_id',source,'season_id',x.season_id,'context_key',rev.bracket_id::text,'source_type','tournament_bracket','source_id',rev.bracket_id,'source_generation',gen,'source_manifest',manifest||jsonb_build_object('participant_id',x.participant_id),'source_hash',md5((manifest||jsonb_build_object('participant_id',x.participant_id))::text),'state','current','achieved_at',achieved,'qualifies',true,'holder',false,'co_holder',false);
    end loop;
   end if;
  end loop;
 elsif rev.source_kind='standings'then
  for x in select c.*,rs.edition_id,ce.team_id,ed.season_id from public.achievement_competition_closures c join public.ranking_scopes rs on rs.id=c.scope_id and rs.state='current'and rs.published_generation=c.generation and rs.target_generation=c.generation and rs.source_hash=c.source_hash join public.competition_editions ed on ed.id=rs.edition_id and ed.organization_id=org join public.competition_entries ce on ce.id=c.champion_entry_id and ce.team_organization_id=org where c.scope_id=rev.standings_scope_id order by c.generation desc limit 1 loop
   subject:=x.team_id::text;ctx:=x.scope_id::text;rk:=subject||':'||ctx;if(p_after is not null and rk<=p_after)or(p_subject is not null and subject<>p_subject)or(p_context is not null and ctx<>p_context)then return;end if;
   manifest:=jsonb_build_object('closure_id',x.id,'scope_id',x.scope_id,'generation',x.generation,'source_hash',x.source_hash,'edition_id',x.edition_id,'champion_entry_id',x.champion_entry_id);
   return next jsonb_build_object('key',rk,'subject_key',subject,'team_id',x.team_id,'season_id',x.season_id,'context_key',ctx,'source_type','standings_scope','source_id',x.scope_id,'source_generation',x.generation,'source_manifest',manifest,'source_hash',md5(manifest::text),'state','current','achieved_at',x.created_at,'qualifies',true,'holder',false,'co_holder',false);
  end loop;
 end if;
end$$;

create function boss_private.achievement_dirty()returns trigger language plpgsql volatile security definer set search_path=''as $$declare org uuid;row_data jsonb:=to_jsonb(coalesce(new,old));begin
 org:=(row_data->>'organization_id')::uuid;
 if org is null and row_data?'edition_id'then select organization_id into org from public.competition_editions where id=(row_data->>'edition_id')::uuid;end if;
 if org is null and row_data?'scope_id'then select e.organization_id into org from public.ranking_scopes s join public.competition_editions e on e.id=s.edition_id where s.id=(row_data->>'scope_id')::uuid;end if;
 if org is not null then update public.achievement_refresh_work set target_generation=target_generation+1,state='pending',cursor=null,updated_at=clock_timestamp()where organization_id=org;end if;
 return coalesce(new,old);
end$$;
create trigger achievement_stat_dirty after insert or update or delete on public.stat_origin_summaries for each row execute function boss_private.achievement_dirty();
create trigger achievement_selection_dirty after insert or update or delete on public.stat_game_selections for each row execute function boss_private.achievement_dirty();
create trigger achievement_rank_dirty after insert or update or delete on public.ranking_scopes for each row execute function boss_private.achievement_dirty();
create trigger achievement_bracket_dirty after insert or update or delete on public.tournament_brackets for each row execute function boss_private.achievement_dirty();
create trigger achievement_advancement_dirty after insert on public.tournament_advancements for each row execute function boss_private.achievement_dirty();

revoke all on function boss_private.achievement_permission(uuid,text,uuid,uuid),boss_private.achievement_lock_authority(uuid,uuid,uuid,uuid),boss_private.achievement_facts(public.achievement_definition_revisions,uuid,text,integer,text,text),boss_private.achievement_dirty()from public,anon,authenticated,service_role;
