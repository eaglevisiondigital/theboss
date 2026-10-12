-- Phase 6B cold-statistics private paging; source authorization remains unchanged.
create index ranking_candidates_generation_page_idx on public.ranking_candidates(scope_id,built_generation,(coalesce(rank,2147483647)),subject_key);
create or replace function boss_private.ranking_read(q jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
<<read_context>>
declare actor uuid;ed uuid;org uuid;definition uuid;product text;group_id uuid;scope public.ranking_scopes;e public.competition_editions;d public.ranking_definitions;
 page_limit int:=50;cursor jsonb;after_rank int;after_id text;after_time timestamptz;history boolean:=false;rows jsonb;next_cursor jsonb;freshness text;catalog jsonb;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.ranking_input(q,array['organization_id','edition_id','product','definition_id','group_id','limit','cursor','history','view']);
 if q?'limit'and(jsonb_typeof(q->'limit')is distinct from'number'or(q->>'limit')::numeric<>trunc((q->>'limit')::numeric))then raise exception 'Invalid page size'using errcode='PT422';end if;
 if q?'view'then
 if q<>jsonb_build_object('view','navigation')then raise exception 'Invalid navigation query'using errcode='PT422';end if;
 return jsonb_build_object('navigation_available',exists(select 1 from public.competition_editions ee where boss_private.ranking_can_edition(actor,'competition.view',ee.id))or exists(select 1 from public.organizations oo where boss_private.ranking_role_permission(actor,'competition.manage',oo.id))or exists(select 1 from public.ranking_definitions dd where boss_private.ranking_can_definition(actor,dd.product||'.view',dd.id)));end if;
 page_limit:=coalesce((q->>'limit')::int,50);if page_limit not between 1 and 100 then raise exception 'Invalid page size'using errcode='PT422';end if;
 ed:=boss_private.ranking_uuid(q,'edition_id');org:=boss_private.ranking_uuid(q,'organization_id');definition:=boss_private.ranking_uuid(q,'definition_id');group_id:=boss_private.ranking_uuid(q,'group_id');product:=q->>'product';history:=coalesce((q->>'history')::boolean,false);
 if ed is null then
 if org is null or q?'product'or q?'definition_id'or q?'group_id'or q?'history'then raise exception 'Organization required for catalog'using errcode='PT422';end if;
 cursor:=q->'cursor';if cursor is not null then perform boss_private.ranking_input(cursor,array['after_id'],array['after_id']);after_id:=boss_private.ranking_uuid(cursor,'after_id')::text;end if;
 perform 1 from public.people where id=actor for share;perform 1 from public.role_assignments where person_id=actor and(organization_id=org or scope_type='platform')order by id for share;perform 1 from public.organization_memberships where person_id=actor and organization_id=org order by id for share;perform 1 from public.team_memberships where person_id=actor and organization_id=org order by id for share;perform 1 from public.competition_access_assignments where person_id=actor order by id for share;perform 1 from public.organization_modules where organization_id=org order by id for share;
 perform boss_private.games_require_live_auth();
 select coalesce(jsonb_agg(jsonb_build_object('id',ee.id,'competition_id',ee.competition_id,'competition_name',c.name,'name',ee.name,'sport_key',ee.sport_key,'season_id',ee.season_id,'cross_organization',ee.cross_organization,'can_manage',boss_private.ranking_can_edition(actor,'competition.manage',ee.id),'can_policy_manage',boss_private.ranking_can_edition(actor,'competition.policy_manage',ee.id))order by ee.id),'[]')into catalog from(select *from public.competition_editions ee where ee.organization_id=org and ee.status='active'and(after_id is null or ee.id>after_id::uuid)and(boss_private.ranking_can_edition(actor,'competition.view',ee.id)or exists(select 1 from public.ranking_definitions dd where dd.edition_id=ee.id and boss_private.ranking_can_definition(actor,dd.product||'.view',dd.id)))order by ee.id limit page_limit+1)ee join public.competitions c on c.id=ee.competition_id;
 if jsonb_array_length(catalog)>page_limit then next_cursor:=jsonb_build_object('after_id',catalog->(page_limit-1)->'id');catalog:=catalog-(jsonb_array_length(catalog)-1);end if;
 return jsonb_build_object('contract','rankings-v1','editions',catalog,'next_cursor',next_cursor,'can_create',boss_private.ranking_role_permission(actor,'competition.manage',org));
 end if;
 select *into e from public.competition_editions where id=ed;org:=e.organization_id;
 if e.id is null then raise exception 'Access denied'using errcode='PT403';end if;
 if product is null then
 if definition is not null or group_id is not null or history then raise exception 'Invalid edition catalog'using errcode='PT422';end if;
 perform boss_private.ranking_lock_authority(actor,ed);perform 1 from public.competition_editions where id=ed for share;perform boss_private.ranking_authorize(actor,'competition.view',ed);
 cursor:=q->'cursor';if cursor is not null then perform boss_private.ranking_input(cursor,array['after_id'],array['after_id']);after_id:=boss_private.ranking_uuid(cursor,'after_id')::text;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',ce.id,'team_id',ce.team_id,'organization_id',ce.team_organization_id,'name',t.name,'status',ce.status,'season_id',ce.season_id)order by ce.id),'[]')into rows from(select *from public.competition_entries ce where ce.edition_id=ed and(after_id is null or ce.id>after_id::uuid)order by ce.id limit page_limit+1)ce join public.teams t on t.id=ce.team_id;
 if jsonb_array_length(rows)>page_limit then next_cursor:=jsonb_build_object('after_id',rows->(page_limit-1)->'id');rows:=rows-(jsonb_array_length(rows)-1);end if;
 return jsonb_build_object('contract','rankings-v1','edition',jsonb_build_object('id',e.id,'competition_id',e.competition_id,'name',e.name,'sport_key',e.sport_key,'season_id',e.season_id,'policy_id',e.standings_policy_id),'entries',rows,'next_cursor',next_cursor,'can_manage',boss_private.ranking_can_edition(actor,'competition.manage',ed),'can_policy_manage',boss_private.ranking_can_edition(actor,'competition.policy_manage',ed),'can_standings_manage',boss_private.ranking_can_edition(actor,'standings.manage',ed),'can_leaderboard_manage',boss_private.ranking_can_edition(actor,'leaderboard.manage',ed),'can_records_manage',boss_private.ranking_can_edition(actor,'records.manage',ed),
 'groups',coalesce((select jsonb_agg(jsonb_build_object('id',gg.id,'kind',gg.kind,'name',gg.name)order by gg.id)from(select *from public.competition_groups where edition_id=ed and status='active'order by id limit 100)gg),'[]'),
 'definitions',coalesce((select jsonb_agg(jsonb_build_object('id',dd.id,'name',dd.name,'product',dd.product,'source_kind',dd.source_kind,'metric_key',dd.metric_key,'team_id',dd.team_id,'season_id',dd.season_id)order by dd.id)from(select *from public.ranking_definitions dd where dd.edition_id=ed and dd.status='active'and boss_private.ranking_can_definition(actor,dd.product||'.view',dd.id)order by dd.id limit 100)dd),'[]'));
 end if;
 if product is null or product<>all(array['standings','leaderboard','records'])then raise exception 'Invalid ranking product'using errcode='PT422';end if;
 if product<>'standings'then select rd.*into d from public.ranking_definitions rd where rd.id=definition and rd.edition_id=ed and rd.product=read_context.product;if d.id is null then raise exception 'Access denied'using errcode='PT403';end if;elsif definition is not null or history then raise exception 'Invalid standings query'using errcode='PT422';end if;
 if group_id is not null and not exists(select 1 from public.competition_groups where id=group_id and edition_id=ed and status='active')then raise exception 'Access denied'using errcode='PT403';end if;
 perform boss_private.ranking_authorize(actor,product||'.view',ed,d.id);perform boss_private.ranking_lock_authority(actor,ed);
 perform 1 from public.competition_editions where id=ed for share;perform boss_private.ranking_authorize(actor,product||'.view',ed,d.id);
 select *into scope from public.ranking_scopes where edition_id=ed and ranking_scopes.product=read_context.product and ranking_scopes.group_id is not distinct from read_context.group_id and definition_id is not distinct from definition;
 freshness:=case when scope.id is null then'unavailable'when scope.valid_until is not null and scope.valid_until<=clock_timestamp()then'pending'when scope.state='current'and scope.published_generation=(select generation from public.competition_editions where id=ed)and scope.source_hash=md5(boss_private.ranking_source_manifest(scope)::text)then'current'when scope.state='refreshing'then'refreshing'else'pending'end;
 cursor:=q->'cursor';if cursor is not null then
 perform boss_private.ranking_input(cursor,array['scope_id','generation','rank','id','recognized_at'],array['scope_id','generation','id']);
 if boss_private.ranking_uuid(cursor,'scope_id')is distinct from scope.id or(cursor->>'generation')::bigint is distinct from scope.published_generation then raise exception 'Cursor no longer current'using errcode='PT409';end if;
 after_rank:=(cursor->>'rank')::int;after_id:=cursor->>'id';after_time:=(cursor->>'recognized_at')::timestamptz;
 if(history and after_time is null)or(not history and after_rank is null)then raise exception 'Invalid cursor'using errcode='PT422';end if;end if;
 if freshness<>'current'then rows:='[]';
 elsif history then
 select coalesce(jsonb_agg(to_jsonb(h)order by h.recognized_at desc,h.id desc),'[]')into rows from(select re.id,coalesce((select coalesce(p.display_name,p.preferred_name)from public.people p where p.id=(re.source_manifest->'sources'->0->>'person_id')::uuid),(select t.name from public.teams t where t.id=(re.source_manifest->'sources'->0->>'team_id')::uuid),'Recorded performance')label,re.subject_key,re.event_type,re.value,re.achieved_at,re.recognized_at,re.source_manifest,re.qualification,re.generation,re.previous_event_id from public.record_events re where re.scope_id=scope.id and(after_time is null or(re.recognized_at,re.id)<(after_time,after_id::uuid))order by re.recognized_at desc,re.id desc limit page_limit+1)h;
 elsif product='standings'then
 select coalesce(jsonb_agg(to_jsonb(r)order by r.rank,r.id),'[]')into rows from(select sr.entry_id id,t.name label,sr.rank,sr.wins,sr.losses,sr.ties,sr.games_played,sr.points,sr.win_percentage,sr.scoring_for,sr.scoring_against,sr.metrics,sr.explanation from public.standings_rows sr join public.competition_entries ce on ce.id=sr.entry_id join public.teams t on t.id=ce.team_id where sr.scope_id=scope.id and(after_rank is null or(sr.rank,sr.entry_id)>(after_rank,after_id::uuid))order by sr.rank,sr.entry_id limit page_limit+1)r;
 else
 -- Resolve one authorized generation page before joining labels/holder details.
 -- Cold planner statistics must not turn 101 requested rows into a whole-pool
 -- person/label join or wide payload sort.
 with page as materialized(select rc.*from public.ranking_candidates rc
 where rc.scope_id=scope.id and rc.built_generation=scope.published_generation
 and(after_rank is null or(coalesce(rc.rank,2147483647),rc.subject_key)>(after_rank,after_id))
 order by coalesce(rc.rank,2147483647),rc.subject_key limit page_limit+1)
 select coalesce(jsonb_agg(to_jsonb(r)order by coalesce(r.rank,2147483647),r.id),'[]')into rows
 from(select rc.subject_key id,coalesce(p.display_name,p.preferred_name,t.name,'Boss participant')label,
 rc.person_id,rc.team_id,rc.rank,rc.value,rc.qualification_state,rc.qualification,rc.coverage,rc.source_manifest,rc.achieved_at,
 case when product='records'then exists(select 1 from public.record_current_holders ch where ch.scope_id=scope.id and ch.candidate_id=rc.id)end current_holder
 from page rc left join public.people p on p.id=rc.person_id left join public.teams t on t.id=rc.team_id)r;
 end if;
 if jsonb_array_length(rows)>page_limit then
 next_cursor:=jsonb_strip_nulls(jsonb_build_object('scope_id',scope.id,'generation',scope.published_generation,'rank',case when not history then coalesce((rows->(page_limit-1)->>'rank')::int,2147483647)end,'id',rows->(page_limit-1)->'id','recognized_at',case when history then rows->(page_limit-1)->'recognized_at'end));rows:=rows-(jsonb_array_length(rows)-1);end if;
 return jsonb_build_object('contract','rankings-v1','edition',jsonb_build_object('id',e.id,'name',e.name,'sport_key',e.sport_key,'season_id',e.season_id),'product',product,'definition',case when d.id is not null then to_jsonb(d)-array['actor_person_id']end,'scope_id',scope.id,'freshness',freshness,'generation',scope.published_generation,'target_generation',scope.target_generation,'source_hash',scope.source_hash,'rows',rows,'next_cursor',next_cursor,'can_rebuild',case when d.id is not null then boss_private.ranking_can_definition(actor,product||'.rebuild',d.id)else boss_private.ranking_can_edition(actor,product||'.rebuild',ed)end,
 'groups',coalesce((select jsonb_agg(jsonb_build_object('id',gg.id,'kind',gg.kind,'name',gg.name)order by gg.name,gg.id)from(select *from public.competition_groups where edition_id=ed and status='active'order by id limit 100)gg),'[]'),
 'definitions',coalesce((select jsonb_agg(jsonb_build_object('id',dd.id,'name',dd.name,'product',dd.product,'source_kind',dd.source_kind,'metric_key',dd.metric_key,'team_id',dd.team_id,'season_id',dd.season_id)order by dd.id)from(select *from public.ranking_definitions dd where dd.edition_id=ed and dd.status='active'and boss_private.ranking_can_definition(actor,dd.product||'.view',dd.id)order by dd.id limit 100)dd),'[]'));
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or datetime_field_overflow then raise exception 'Invalid ranking query'using errcode='PT422';end$$;
