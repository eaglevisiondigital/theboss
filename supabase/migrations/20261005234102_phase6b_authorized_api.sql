-- Finite private comparative RPCs. Knowing a resource identifier creates no authority.
create function boss_private.ranking_input(i jsonb,allowed text[],required text[]default'{}')returns void language plpgsql immutable set search_path=''as $$
declare field text;begin
 if i is null or jsonb_typeof(i)is distinct from'object'or octet_length(i::text)>16384 or not(i?&required)or exists(select 1 from jsonb_object_keys(i)k where k<>all(allowed))or exists(select 1 from jsonb_each(i)e where jsonb_typeof(e.value)='null')then raise exception 'Invalid ranking input'using errcode='PT422';end if;
 foreach field in array array['cross_organization','counts_for_standings','competition_only','allow_partial','history']loop
 if i?field and jsonb_typeof(i->field)is distinct from'boolean'then raise exception 'Invalid Boolean field'using errcode='PT422';end if;end loop;
 foreach field in array array['amount','standings_primary_score','standings_opponent_score','limit','rank','generation']loop
 if i?field and jsonb_typeof(i->field)is distinct from'number'then raise exception 'Invalid numeric field'using errcode='PT422';end if;end loop;
 foreach field in array array['action','name','reason','sport_key','kind','outcome','game_type','team_result_audience','product','source_kind','metric_key','metric_kind','direction','starts_at','ends_at','effective_at','recognized_at']loop
 if i?field and jsonb_typeof(i->field)is distinct from'string'then raise exception 'Invalid text field'using errcode='PT422';end if;end loop;
end$$;
create function boss_private.ranking_uuid(i jsonb,k text)returns uuid language plpgsql immutable set search_path=''as $$
begin if not i?k then return null;end if;if jsonb_typeof(i->k)is distinct from'string'then raise exception 'Invalid resource identifier'using errcode='PT422';end if;return(i->>k)::uuid;
exception when invalid_text_representation then raise exception 'Invalid resource identifier'using errcode='PT422';end$$;
create function boss_private.ranking_authorize(actor uuid,k text,edition uuid,definition uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$
begin
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.current_person_id()or not(case when definition is not null then exists(select 1 from public.ranking_definitions where id=definition and edition_id=edition)and boss_private.ranking_can_definition(actor,k,definition)else boss_private.ranking_can_edition(actor,k,edition)end)then raise exception 'Access denied'using errcode='PT403';end if;
end$$;
create function boss_private.ranking_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
<<write_context>>
declare actor uuid;request uuid;i jsonb;action text;org uuid;ed uuid;resource uuid;comp uuid;team public.teams;e public.competition_editions;g public.games;a public.competition_game_assignments;
 primary_entry public.competition_entries;opponent_entry public.competition_entries;entry public.competition_entries;d public.ranking_definitions;r public.competition_rulings;scope public.ranking_scopes;
 group_ids uuid[];field text;permission text;result jsonb;receipt boss_private.ranking_operation_receipts;input_hash text;rev bigint;configuration jsonb;complete boolean;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.ranking_input(command,array['action','request_id','input'],array['action','request_id','input']);
 if jsonb_typeof(command->'action')is distinct from'string'then raise exception 'Invalid action'using errcode='PT422';end if;
 request:=boss_private.ranking_uuid(command,'request_id');i:=command->'input';action:=command->>'action';input_hash:=md5(command::text);
 -- Serialize actor-bound idempotency before canonical locks; no other operation uses this key.
 perform pg_advisory_xact_lock(hashtextextended('boss-ranking-request:'||actor::text||':'||request::text,0));
 select *into receipt from boss_private.ranking_operation_receipts where actor_person_id=actor and request_id=request;
 if receipt.actor_person_id is not null then
 if receipt.input_hash<>input_hash then raise exception 'Receipt conflict'using errcode='PT409';end if;
 -- A replay never bypasses current authority, even though it writes nothing.
 ed:=boss_private.ranking_uuid(receipt.result,'edition_id');org:=boss_private.ranking_uuid(receipt.result,'organization_id');
 if ed is not null then
 permission:=receipt.result->>'permission';perform boss_private.ranking_lock_authority(actor,ed);perform boss_private.ranking_authorize(actor,permission,ed,boss_private.ranking_uuid(receipt.result,'definition_id'));
 elsif not boss_private.ranking_role_permission(actor,'competition.manage',org)then raise exception 'Access denied'using errcode='PT403';end if;
 return receipt.result||jsonb_build_object('replayed',true);end if;
 if action='competition.create'then
 perform boss_private.ranking_input(i,array['organization_id','parent_unit_id','name'],array['organization_id','name']);org:=boss_private.ranking_uuid(i,'organization_id');
 perform 1 from public.people where id=actor for share;perform 1 from public.role_assignments where person_id=actor order by id for share;
 perform 1 from public.organization_memberships where person_id=actor and organization_id=org order by id for share;perform 1 from public.organization_modules where organization_id=org order by id for share;
 perform boss_private.games_require_live_auth();if not boss_private.ranking_role_permission(actor,'competition.manage',org,boss_private.ranking_uuid(i,'parent_unit_id'))then raise exception 'Access denied'using errcode='PT403';end if;
 insert into public.competitions(organization_id,parent_unit_id,name,created_by_person_id)values(org,boss_private.ranking_uuid(i,'parent_unit_id'),i->>'name',actor)returning id into resource;permission:='competition.manage';
 elsif action='edition.create'then
 perform boss_private.ranking_input(i,array['competition_id','sport_key','season_id','name','cross_organization','team_result_audience','starts_at','ends_at'],array['competition_id','sport_key','name']);comp:=boss_private.ranking_uuid(i,'competition_id');
 select organization_id into org from public.competitions where id=comp and status='active';
 perform 1 from public.people where id=actor for share;perform 1 from public.role_assignments where person_id=actor order by id for share;perform 1 from public.organization_memberships where person_id=actor and organization_id=org order by id for share;perform 1 from public.competition_access_assignments where person_id=actor and competition_id=comp order by id for share;perform 1 from public.organization_modules where organization_id=org order by id for share;
 perform boss_private.games_require_live_auth();
 if not coalesce(boss_private.ranking_role_permission(actor,'competition.manage',org,(select parent_unit_id from public.competitions where id=comp)),false)and not exists(select 1 from public.competition_access_assignments aa join public.roles rr on rr.id=aa.role_id and rr.key='competition_manager'and rr.status='active'where aa.person_id=actor and aa.competition_id=comp and aa.edition_id is null and aa.status='active'and aa.starts_at<=clock_timestamp()and(aa.ends_at is null or aa.ends_at>clock_timestamp()))then raise exception 'Access denied'using errcode='PT403';end if;
 insert into public.competition_editions(competition_id,organization_id,sport_key,season_id,name,cross_organization,team_result_audience,starts_at,ends_at)values(comp,org,i->>'sport_key',boss_private.ranking_uuid(i,'season_id'),i->>'name',coalesce((i->>'cross_organization')::boolean,false),coalesce(i->>'team_result_audience','managers'),(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz)returning id into ed;resource:=ed;permission:='competition.manage';
 else
 ed:=boss_private.ranking_uuid(i,'edition_id');select *into e from public.competition_editions where id=ed;org:=e.organization_id;
 if e.id is null then raise exception 'Access denied'using errcode='PT403';end if;
 -- Source game lock order is identical to existing Game Center writes.
 if action='game.assign'then
 select *into g from public.games where id=boss_private.ranking_uuid(i,'game_id');
 perform 1 from public.events where id=g.event_id for update;select *into g from public.games where id=g.id for update;
 end if;
 if action='ranking.rebuild'then
 perform boss_private.ranking_input(i,array['edition_id','product','group_id','definition_id'],array['edition_id','product']);
 if i->>'product'<>all(array['standings','leaderboard','records'])then raise exception 'Invalid product'using errcode='PT422';end if;
 permission:=i->>'product'||'.rebuild';d:=null;
 if i->>'product'<>'standings'then select *into d from public.ranking_definitions where id=boss_private.ranking_uuid(i,'definition_id')and edition_id=ed and product=i->>'product';if d.id is null then raise exception 'Access denied'using errcode='PT403';end if;end if;
 perform boss_private.ranking_authorize(actor,permission,ed,d.id);
 insert into public.ranking_scopes(edition_id,product,group_id,definition_id,target_generation)values(ed,i->>'product',boss_private.ranking_uuid(i,'group_id'),d.id,e.generation)on conflict(edition_id,product,group_id,definition_id)do nothing;
 select *into scope from public.ranking_scopes where edition_id=ed and product=i->>'product'and group_id is not distinct from boss_private.ranking_uuid(i,'group_id')and definition_id is not distinct from d.id;
 complete:=boss_private.ranking_refresh(scope.id,actor);perform boss_private.ranking_authorize(actor,permission,ed,d.id);resource:=scope.id;
 result:=jsonb_build_object('complete',complete,'scope_id',scope.id,'definition_id',d.id,'freshness',case when complete then'current'else'pending'end);
 else
 perform boss_private.ranking_lock_authority(actor,ed);select *into e from public.competition_editions where id=ed for update;
 if action='definition.end'then select *into d from public.ranking_definitions where id=boss_private.ranking_uuid(i,'definition_id')and edition_id=ed;end if;
 permission:=case when action='definition.end'then d.product||'.manage'when action in('policy.activate')then'competition.policy_manage'when action in('game.assign','ruling.create')then'standings.manage'when action='definition.create'then(i->>'product')||'.manage'else'competition.manage'end;
 if action<>'entry.approve'then perform boss_private.ranking_authorize(actor,permission,ed,case when action='definition.end'then d.id end);end if;
 case action
 when'group.create'then
 perform boss_private.ranking_input(i,array['edition_id','kind','name','organization_unit_id'],array['edition_id','kind','name']);
 insert into public.competition_groups(edition_id,organization_id,kind,name,organization_unit_id)values(ed,org,i->>'kind',i->>'name',boss_private.ranking_uuid(i,'organization_unit_id'))returning id into resource;
 when'entry.create'then
 perform boss_private.ranking_input(i,array['edition_id','team_id'],array['edition_id','team_id']);select *into team from public.teams where id=boss_private.ranking_uuid(i,'team_id')and status='active';
 if team.id is null or(team.organization_id<>org and not e.cross_organization)or(team.organization_id=org and e.season_id is not null and team.season_id is distinct from e.season_id)then raise exception 'Invalid competition team'using errcode='PT422';end if;
 insert into public.competition_entries(edition_id,team_organization_id,team_id,season_id,status,approved_by_person_id)values(ed,team.organization_id,team.id,team.season_id,case when boss_private.games_role_permission(actor,'organization.manage',team.organization_id,team.id)then'active'else'pending'end,case when boss_private.games_role_permission(actor,'organization.manage',team.organization_id,team.id)then actor end)returning id into resource;
 when'entry.approve'then
 perform boss_private.ranking_input(i,array['edition_id','entry_id'],array['edition_id','entry_id']);select *into entry from public.competition_entries where id=boss_private.ranking_uuid(i,'entry_id')and edition_id=ed for update;
 if entry.id is null or entry.status<>'pending'or not boss_private.games_role_permission(actor,'organization.manage',entry.team_organization_id,entry.team_id)then raise exception 'Access denied'using errcode='PT403';end if;
 update public.competition_entries set status='active',approved_by_person_id=actor,version=version+1 where id=entry.id;resource:=entry.id;permission:='competition.view';
 when'entry.end'then
 perform boss_private.ranking_input(i,array['edition_id','entry_id'],array['edition_id','entry_id']);
 update public.competition_entries set status='inactive',ended_at=greatest(clock_timestamp(),entered_at+interval'1 microsecond'),version=version+1 where id=boss_private.ranking_uuid(i,'entry_id')and edition_id=ed returning id into resource;
 when'group.assign'then
 perform boss_private.ranking_input(i,array['edition_id','entry_id','group_id','starts_at','ends_at'],array['edition_id','entry_id','group_id']);
 if not exists(select 1 from public.competition_entries where id=boss_private.ranking_uuid(i,'entry_id')and edition_id=ed and status='active')or not exists(select 1 from public.competition_groups where id=boss_private.ranking_uuid(i,'group_id')and edition_id=ed and status='active')then raise exception 'Invalid group assignment'using errcode='PT422';end if;
 insert into public.competition_entry_groups(edition_id,entry_id,group_id,starts_at,ends_at)values(ed,boss_private.ranking_uuid(i,'entry_id'),boss_private.ranking_uuid(i,'group_id'),coalesce((i->>'starts_at')::timestamptz,clock_timestamp()),(i->>'ends_at')::timestamptz)returning id into resource;
 when'group.end'then
 perform boss_private.ranking_input(i,array['edition_id','membership_id'],array['edition_id','membership_id']);update public.competition_entry_groups set status='inactive',ends_at=greatest(clock_timestamp(),starts_at+interval'1 microsecond')where id=boss_private.ranking_uuid(i,'membership_id')and edition_id=ed returning id into resource;
 when'policy.activate'then
 perform boss_private.ranking_input(i,array['edition_id','configuration','reason'],array['edition_id','configuration','reason']);configuration:=i->'configuration';
 if not boss_private.ranking_validate_policy(configuration)or configuration->>'template'<>e.sport_key or exists(select 1 from jsonb_array_elements(configuration->'tiebreaks')t where t?'group_id'and not exists(select 1 from public.competition_groups gg where gg.id=(t->>'group_id')::uuid and gg.edition_id=ed and gg.status='active'and gg.kind=case t->>'type'when'conference_percentage'then'conference'when'division_percentage'then'division'else gg.kind end))then raise exception 'Invalid standings policy'using errcode='PT422';end if;
 insert into public.standings_policy_revisions(edition_id,version,configuration,reason,actor_person_id)select ed,coalesce(max(version),0)+1,write_context.configuration,i->>'reason',actor from public.standings_policy_revisions where edition_id=ed returning id into resource;
 update public.competition_editions set standings_policy_id=resource,version=version+1 where id=ed;perform boss_private.ranking_dirty_edition(ed);
 when'game.assign'then
 perform boss_private.ranking_input(i,array['edition_id','game_id','primary_entry_id','opponent_entry_id','game_type','counts_for_standings','group_ids','reason'],array['edition_id','game_id','primary_entry_id','opponent_entry_id','game_type','counts_for_standings','reason']);
 if g.id is null or not boss_private.games_permission(actor,'games.manage',g,true)then raise exception 'Access denied'using errcode='PT403';end if;
 select *into primary_entry from public.competition_entries where id=boss_private.ranking_uuid(i,'primary_entry_id')and edition_id=ed and status='active'and entered_at<=clock_timestamp()and(ended_at is null or ended_at>clock_timestamp());
 select *into opponent_entry from public.competition_entries where id=boss_private.ranking_uuid(i,'opponent_entry_id')and edition_id=ed and status='active'and entered_at<=clock_timestamp()and(ended_at is null or ended_at>clock_timestamp());
 if primary_entry.id is null or opponent_entry.id is null or primary_entry.id=opponent_entry.id or primary_entry.team_id<>g.primary_team_id or primary_entry.team_organization_id<>g.organization_id or g.sport_key<>e.sport_key or(e.season_id is not null and g.organization_id=org and g.season_id is distinct from e.season_id)or(g.opponent_team_id is not null and opponent_entry.team_id<>g.opponent_team_id)or(g.opponent_team_id is null and(g.external_opponent_name is null or not e.cross_organization or opponent_entry.team_organization_id=g.organization_id))then raise exception 'Invalid explicit game assignment'using errcode='PT422';end if;
 if i?'group_ids'and(jsonb_typeof(i->'group_ids')is distinct from'array'or jsonb_array_length(i->'group_ids')>16)then raise exception 'Invalid groups'using errcode='PT422';end if;
 select array_agg(distinct(value#>>'{}')::uuid)into group_ids from jsonb_array_elements(coalesce(i->'group_ids','[]'));
 if exists(select 1 from unnest(group_ids)gids(value) where not exists(select 1 from public.competition_groups gg where gg.id=gids.value and gg.edition_id=ed and gg.status='active')or exists(select 1 from unnest(array[primary_entry.id,opponent_entry.id])en where not exists(select 1 from public.competition_entry_groups eg where eg.entry_id=en and eg.group_id=gids.value and eg.status='active'and eg.starts_at<=clock_timestamp()and(eg.ends_at is null or eg.ends_at>clock_timestamp()))))then raise exception 'Invalid explicit game group'using errcode='PT422';end if;
 insert into public.competition_game_assignments(edition_id,source_organization_id,game_id,version,primary_entry_id,opponent_entry_id,game_type,counts_for_standings,source_consent_by_person_id,reason,actor_person_id)
 select ed,g.organization_id,g.id,coalesce(max(version),0)+1,primary_entry.id,opponent_entry.id,i->>'game_type',(i->>'counts_for_standings')::boolean,actor,i->>'reason',actor from public.competition_game_assignments where edition_id=ed and game_id=g.id returning id into resource;
 insert into public.competition_game_assignment_groups(edition_id,assignment_id,group_id)select ed,resource,id from unnest(group_ids)id;
 when'ruling.create'then
 perform boss_private.ranking_input(i,array['edition_id','group_id','assignment_id','primary_entry_id','opponent_entry_id','kind','outcome','amount','standings_primary_score','standings_opponent_score','reversal_of_id','effective_at','reason'],array['edition_id','primary_entry_id','kind','reason']);
 if i->>'kind'='reversal'then
 select *into r from public.competition_rulings where id=boss_private.ranking_uuid(i,'reversal_of_id')and edition_id=ed and kind<>'reversal';if r.id is null then raise exception 'Invalid reversal'using errcode='PT422';end if;
 elsif i->>'kind'in('forfeit','result_override','vacated')then
 if i->>'kind'='forfeit'and not i?'assignment_id'then
 if not i?&array['opponent_entry_id','outcome']then raise exception 'Invalid unplayed forfeit'using errcode='PT422';end if;
 elsif not i?'assignment_id'then raise exception 'An assigned result is required'using errcode='PT422';end if;
 if i->>'kind'<>'vacated'and not i?'outcome'then raise exception 'Outcome required'using errcode='PT422';end if;
 if i?'assignment_id'then select *into a from public.competition_game_assignments where id=boss_private.ranking_uuid(i,'assignment_id')and edition_id=ed;
 if a.id is null or a.primary_entry_id is distinct from boss_private.ranking_uuid(i,'primary_entry_id')or a.opponent_entry_id is distinct from boss_private.ranking_uuid(i,'opponent_entry_id')then raise exception 'Invalid result scope'using errcode='PT422';end if;end if;
 elsif not i?'amount'then raise exception 'Finite adjustment required'using errcode='PT422';end if;
 if i->>'kind'='eligibility'and(i->>'amount')::numeric not in(0,1)then raise exception 'Eligibility must explicitly be zero or one'using errcode='PT422';end if;
 if i?'amount'and i->>'kind'in('win_adjustment','loss_adjustment','tie_resolution')and(i->>'amount')::numeric<>trunc((i->>'amount')::numeric)then raise exception 'Whole result adjustment required'using errcode='PT422';end if;
 if i?'standings_primary_score'or i?'standings_opponent_score'then
 select spr.configuration into configuration from public.standings_policy_revisions spr where spr.id=e.standings_policy_id;
 if i->>'kind'<>'forfeit'or not i?&array['standings_primary_score','standings_opponent_score']or not coalesce(configuration?'forfeit_score',false)or jsonb_build_array(i->'standings_primary_score',i->'standings_opponent_score')<>jsonb_build_array(configuration->'forfeit_score'->case when i->>'outcome'='opponent'then 1 else 0 end,configuration->'forfeit_score'->case when i->>'outcome'='opponent'then 0 else 1 end) then raise exception 'Standings score must match explicit forfeit policy'using errcode='PT422';end if;end if;
 if i->>'kind'='tie_resolution'then select spr.configuration into configuration from public.standings_policy_revisions spr where spr.id=e.standings_policy_id;if not coalesce((configuration->>'allow_manual_resolution')::boolean,false)then raise exception 'Administrative tiebreak disabled'using errcode='PT422';end if;end if;
 insert into public.competition_rulings(edition_id,group_id,assignment_id,primary_entry_id,opponent_entry_id,kind,outcome,amount,standings_primary_score,standings_opponent_score,reversal_of_id,effective_at,reason,actor_person_id)
 values(ed,boss_private.ranking_uuid(i,'group_id'),boss_private.ranking_uuid(i,'assignment_id'),boss_private.ranking_uuid(i,'primary_entry_id'),boss_private.ranking_uuid(i,'opponent_entry_id'),i->>'kind',i->>'outcome',(i->>'amount')::numeric,(i->>'standings_primary_score')::int,(i->>'standings_opponent_score')::int,boss_private.ranking_uuid(i,'reversal_of_id'),coalesce((i->>'effective_at')::timestamptz,clock_timestamp()),i->>'reason',actor)returning id into resource;
 when'definition.create'then
 perform boss_private.ranking_input(i,array['edition_id','source_organization_id','team_id','season_id','product','source_kind','name','metric_key','metric_kind','direction','qualification','competition_only','allow_partial'],array['edition_id','source_organization_id','product','source_kind','name','metric_key','metric_kind','direction','qualification']);
 if i->>'product'<>all(array['leaderboard','records'])or not boss_private.ranking_role_permission(actor,permission,boss_private.ranking_uuid(i,'source_organization_id'),(select parent_unit_id from public.teams where id=boss_private.ranking_uuid(i,'team_id')),boss_private.ranking_uuid(i,'team_id'))then raise exception 'Access denied'using errcode='PT403';end if;
 if not boss_private.ranking_validate_qualification(i->'qualification',i->>'metric_kind'='rate')then raise exception 'Invalid qualification policy'using errcode='PT422';end if;
 if(i->>'metric_kind'='rate'and not(boss_private.stat_rates(e.sport_key,'[]')? (i->>'metric_key')))or(i->>'metric_kind'='count'and not exists(select 1 from public.game_stat_catalog_items where sport_key=e.sport_key and key=i->>'metric_key'and definition->>'classification'in('required','optional','derived','advanced')and boss_private.ranking_rate_keys(key)is null))then raise exception 'Unsupported statistic'using errcode='PT422';end if;
 if exists(select 1 from jsonb_array_elements(coalesce(i->'qualification'->'thresholds','[]'))t where boss_private.ranking_threshold_metric(t)is not null and not exists(select 1 from public.game_stat_catalog_items where sport_key=e.sport_key and key=boss_private.ranking_threshold_metric(t)))then raise exception 'Unsupported threshold metric'using errcode='PT422';end if;
 insert into public.ranking_definitions(edition_id,source_organization_id,team_id,season_id,product,source_kind,name,metric_key,metric_kind,direction,qualification,competition_only,allow_partial,actor_person_id)
 values(ed,boss_private.ranking_uuid(i,'source_organization_id'),boss_private.ranking_uuid(i,'team_id'),boss_private.ranking_uuid(i,'season_id'),i->>'product',i->>'source_kind',i->>'name',i->>'metric_key',i->>'metric_kind',i->>'direction',i->'qualification',coalesce((i->>'competition_only')::boolean,true),coalesce((i->>'allow_partial')::boolean,false),actor)returning id into resource;
 select *into d from public.ranking_definitions where id=resource;
 if not boss_private.ranking_can_definition(actor,permission,d.id)then raise exception 'Access denied'using errcode='PT403';end if;
 when'definition.end'then
 perform boss_private.ranking_input(i,array['edition_id','definition_id'],array['edition_id','definition_id']);select *into d from public.ranking_definitions where id=boss_private.ranking_uuid(i,'definition_id')and edition_id=ed;
 perform boss_private.ranking_authorize(actor,d.product||'.manage',ed,d.id);
 perform boss_private.ranking_record_event(d.id,h.subject_key,'policy_superseded',ev.value,ev.achieved_at,ev.source_manifest,ev.qualification,e.generation,ev.id,h.scope_id)from public.record_current_holders h join public.record_events ev on ev.id=h.event_id where h.definition_id=d.id;
 delete from public.record_current_holders where definition_id=d.id;
 delete from public.ranking_refresh_work where scope_id in(select id from public.ranking_scopes where definition_id=d.id);
 update public.ranking_definitions set status='inactive',version=version+1 where id=d.id returning id into resource;permission:=d.product||'.manage';
 when'access.grant'then
 perform boss_private.ranking_input(i,array['edition_id','person_id','ends_at'],array['edition_id','person_id','ends_at']);
 if not boss_private.ranking_role_permission(actor,'competition.manage',org)then raise exception 'Access denied'using errcode='PT403';end if;
 insert into public.competition_access_assignments(competition_id,edition_id,person_id,role_id,ends_at,granted_by_person_id)values(e.competition_id,ed,boss_private.ranking_uuid(i,'person_id'),(select id from public.roles where key='competition_manager'),(i->>'ends_at')::timestamptz,actor)returning id into resource;
 when'access.end'then
 perform boss_private.ranking_input(i,array['edition_id','assignment_id'],array['edition_id','assignment_id']);if not boss_private.ranking_role_permission(actor,'competition.manage',org)then raise exception 'Access denied'using errcode='PT403';end if;
 update public.competition_access_assignments set status='inactive',ends_at=greatest(clock_timestamp(),starts_at+interval'1 microsecond')where id=boss_private.ranking_uuid(i,'assignment_id')and edition_id=ed returning id into resource;
 when'edition.archive'then
 perform boss_private.ranking_input(i,array['edition_id'],array['edition_id']);update public.competition_editions set status='archived',version=version+1 where id=ed returning id into resource;perform boss_private.ranking_dirty_edition(ed);
 delete from public.ranking_refresh_work where scope_id in(select id from public.ranking_scopes where edition_id=ed);
 else raise exception 'Unknown ranking action'using errcode='PT422';end case;
 end if;
 end if;
 if resource is null then raise exception 'Resource unavailable'using errcode='PT403';end if;
 result:=jsonb_strip_nulls(coalesce(result,'{}')||jsonb_build_object('contract','rankings-v1','id',resource,'edition_id',ed,'organization_id',org,'permission',permission,'action',action,'replayed',false,'definition_id',d.id));
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,after_data,request_id)
 values(org,actor,auth.uid(),'ranking.'||action,'ranking',resource,'organization',org,jsonb_build_object('edition_id',ed,'action',action,'request_id',request),request);
 insert into boss_private.ranking_operation_receipts(actor_person_id,request_id,input_hash,result)values(actor,request,input_hash,result);
 return result;
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or datetime_field_overflow or check_violation or not_null_violation or foreign_key_violation then raise exception 'Invalid ranking input'using errcode='PT422';
 when unique_violation then raise exception 'Ranking conflict'using errcode='PT409';end$$;
create function boss_private.ranking_read(q jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
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
 select coalesce(jsonb_agg(to_jsonb(r)order by coalesce(r.rank,2147483647),r.id),'[]')into rows from(select rc.subject_key id,coalesce(p.display_name,p.preferred_name,t.name,'Boss participant')label,rc.person_id,rc.team_id,rc.rank,rc.value,rc.qualification_state,rc.qualification,rc.coverage,rc.source_manifest,rc.achieved_at,
 case when product='records'then exists(select 1 from public.record_current_holders ch where ch.scope_id=scope.id and ch.candidate_id=rc.id)end current_holder
 from public.ranking_candidates rc left join public.people p on p.id=rc.person_id left join public.teams t on t.id=rc.team_id where rc.scope_id=scope.id and rc.built_generation=scope.published_generation and(after_rank is null or(coalesce(rc.rank,2147483647),rc.subject_key)>(after_rank,after_id))order by coalesce(rc.rank,2147483647),rc.subject_key limit page_limit+1)r;
 end if;
 if jsonb_array_length(rows)>page_limit then
 next_cursor:=jsonb_strip_nulls(jsonb_build_object('scope_id',scope.id,'generation',scope.published_generation,'rank',case when not history then coalesce((rows->(page_limit-1)->>'rank')::int,2147483647)end,'id',rows->(page_limit-1)->'id','recognized_at',case when history then rows->(page_limit-1)->'recognized_at'end));rows:=rows-(jsonb_array_length(rows)-1);end if;
 return jsonb_build_object('contract','rankings-v1','edition',jsonb_build_object('id',e.id,'name',e.name,'sport_key',e.sport_key,'season_id',e.season_id),'product',product,'definition',case when d.id is not null then to_jsonb(d)-array['actor_person_id']end,'scope_id',scope.id,'freshness',freshness,'generation',scope.published_generation,'target_generation',scope.target_generation,'source_hash',scope.source_hash,'rows',rows,'next_cursor',next_cursor,'can_rebuild',case when d.id is not null then boss_private.ranking_can_definition(actor,product||'.rebuild',d.id)else boss_private.ranking_can_edition(actor,product||'.rebuild',ed)end,
 'groups',coalesce((select jsonb_agg(jsonb_build_object('id',gg.id,'kind',gg.kind,'name',gg.name)order by gg.name,gg.id)from(select *from public.competition_groups where edition_id=ed and status='active'order by id limit 100)gg),'[]'),
 'definitions',coalesce((select jsonb_agg(jsonb_build_object('id',dd.id,'name',dd.name,'product',dd.product,'source_kind',dd.source_kind,'metric_key',dd.metric_key,'team_id',dd.team_id,'season_id',dd.season_id)order by dd.id)from(select *from public.ranking_definitions dd where dd.edition_id=ed and dd.status='active'and boss_private.ranking_can_definition(actor,dd.product||'.view',dd.id)order by dd.id limit 100)dd),'[]'));
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or datetime_field_overflow then raise exception 'Invalid ranking query'using errcode='PT422';end$$;
create function public.boss_ranking_read(p_query jsonb default'{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.ranking_read(p_query)$$;
create function public.boss_ranking_mutate(p_command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.ranking_mutate(p_command)$$;
do $$declare f record;begin
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where(n.nspname='boss_private'and p.proname like'ranking_%')or(n.nspname='public'and p.proname in('boss_ranking_read','boss_ranking_mutate'))loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.sig);end loop;
end$$;
grant execute on function boss_private.ranking_read(jsonb),boss_private.ranking_mutate(jsonb),public.boss_ranking_read(jsonb),public.boss_ranking_mutate(jsonb)to authenticated;
