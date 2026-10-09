-- Add a bounded sealed source; existing self/guardian authorization is unchanged.
alter function boss_private.athlete_history_rows(uuid,text,uuid,timestamptz,uuid,uuid,integer)rename to athlete_history_rows_phase5d;
create function boss_private.athlete_history_rows(p_person uuid,p_sport text,p_season uuid,p_before_time timestamptz,p_before_finalization uuid,p_before_stat uuid,p_limit integer)
returns table(sealed_at timestamptz,finalization_id uuid,stat_id uuid,payload jsonb)
language sql stable security definer set search_path=''as $$
select h.sealed_at,h.finalization_id,h.stat_id,h.payload from(
select v.sealed_at,v.finalization_id,v.stat_id,v.payload||jsonb_build_object('coverage_reason','legacy_unknown')payload from boss_private.athlete_history_rows_phase5d(p_person,p_sport,p_season,p_before_time,p_before_finalization,p_before_stat,p_limit)v
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
 join public.game_volleyball_final_stats s on s.roster_id=r.id and s.organization_id=r.organization_id and s.game_id=r.game_id
 join public.game_volleyball_finalizations f on f.finalization_id=s.finalization_id and f.organization_id=s.organization_id and f.game_id=s.game_id
 join public.game_finalizations cf on cf.id=f.finalization_id and cf.organization_id=f.organization_id and cf.game_id=f.game_id
  and cf.epoch=f.epoch and cf.roster_revision=f.roster_revision
 join public.game_finalization_tracking_seals se on se.finalization_id=cf.id and se.side=s.side and se.game_id=s.game_id and se.organization_id=s.organization_id
 join public.games g on g.id=r.game_id and g.organization_id=r.organization_id and g.sport_key='volleyball'
 join public.organizations o on o.id=g.organization_id
 join public.teams t on t.id=r.team_id and t.organization_id=r.organization_id
 left join public.seasons ts on ts.id=t.season_id and ts.organization_id=t.organization_id
 left join public.seasons gs on gs.id=g.season_id and gs.organization_id=g.organization_id
 where r.person_id=p_person and r.revision=f.roster_revision and f.engine_version='volleyball-v1'
 and r.team_id=case s.side when 'primary' then g.primary_team_id else g.opponent_team_id end
 and(p_sport is null or p_sport='volleyball') and(p_season is null or t.season_id=p_season)
 and(p_before_time is null or(cf.created_at,cf.id,s.id)<(p_before_time,p_before_finalization,p_before_stat))

)h order by h.sealed_at desc,h.finalization_id desc,h.stat_id desc limit p_limit
$$;
revoke all on function boss_private.athlete_history_rows(uuid,text,uuid,timestamptz,uuid,uuid,integer)from public,anon,authenticated,service_role;
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
 if page_limit not between 1 and 50 or(sport is not null and sport<>all(array['basketball','soccer','football','volleyball']))
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

