-- Finite policy, live authority and bounded Phase 6A composition contracts.
create function boss_private.ranking_role_permission(actor uuid,k text,org uuid,unit_id uuid default null,team uuid default null)returns boolean
language sql volatile security definer set search_path=''as $$
 select k=any(boss_private.ranking_permission_keys())and exists(select 1 from public.people where id=actor and status='active')
 and exists(select 1 from public.organizations where id=org and status='active')and boss_private.games_module_live(org,'sports')
 and(team is null or exists(select 1 from public.teams where id=team and organization_id=org and status='active'and parent_unit_id is not distinct from unit_id))
 and(unit_id is null or exists(select 1 from public.organization_units where id=unit_id and organization_id=org and status='active'))
 and exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.key=k and p.status='active'
 where a.person_id=actor and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and(
 (a.scope_type='platform'and a.scope_id is null and a.organization_id is null)
 or(a.organization_id=org and(
 (a.scope_type='organization'and a.scope_id=org and exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())))
 or(a.scope_type='organization_unit'and a.scope_id=unit_id and exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())))
 or(a.scope_type='team'and a.scope_id=team and exists(select 1 from public.team_memberships m where m.organization_id=org and m.team_id=team and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())))))))
$$;
create function boss_private.ranking_can_edition(actor uuid,k text,edition uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.competition_editions e join public.competitions c on c.id=e.competition_id where e.id=edition and e.status='active'and(e.starts_at is null or e.starts_at<=clock_timestamp())and(e.ends_at is null or e.ends_at>clock_timestamp())and c.status='active'and boss_private.games_module_live(e.organization_id,'sports')and(
 boss_private.ranking_role_permission(actor,k,e.organization_id,c.parent_unit_id)
 or exists(select 1 from public.competition_access_assignments a join public.roles r on r.id=a.role_id and r.key='competition_manager'and r.status='active'and r.allowed_scope_types @> array[case when a.edition_id is null then'competition'else'competition_edition'end]join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.key=k and p.status='active'join public.people person on person.id=a.person_id and person.status='active'
 where a.person_id=actor and a.competition_id=c.id and(a.edition_id is null or a.edition_id=e.id)and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()))
 or(k in('competition.view','standings.view')and e.team_result_audience='entry_teams'and exists(select 1 from public.competition_entries ce where ce.edition_id=e.id and ce.status='active'and ce.entered_at<=clock_timestamp()and(ce.ended_at is null or ce.ended_at>clock_timestamp())and(boss_private.games_team_related(actor,ce.team_organization_id,ce.team_id)or boss_private.ranking_role_permission(actor,k,ce.team_organization_id,(select parent_unit_id from public.teams where id=ce.team_id),ce.team_id))))))
$$;
create function boss_private.ranking_can_definition(actor uuid,k text,definition uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.ranking_definitions d join public.competition_editions e on e.id=d.edition_id left join public.teams t on t.id=d.team_id where d.id=definition and d.status='active'and e.status='active'and not e.athlete_cross_organization
 and boss_private.ranking_role_permission(actor,k,d.source_organization_id,t.parent_unit_id,d.team_id)
 and boss_private.games_feature(d.source_organization_id,'game_center')and boss_private.games_module_live(d.source_organization_id,'calendar')and boss_private.games_feature(d.source_organization_id,e.sport_key||'_stats')and boss_private.games_feature(d.source_organization_id,e.sport_key||'_live_scoring')
 and boss_private.games_role_permission(actor,'games.view',d.source_organization_id,d.team_id)
 and(d.source_kind like'team_%'or boss_private.games_role_permission(actor,'team.roster.view',d.source_organization_id,d.team_id))
 and not exists(select 1 from(select distinct x.game_id from public.stat_game_contributions x join public.stat_game_selections gs on gs.game_id=x.game_id and gs.finalization_id=x.finalization_id
 where x.organization_id=d.source_organization_id and x.sport_key=e.sport_key and(d.team_id is null or x.team_id=d.team_id)and(d.season_id is null or x.season_id=d.season_id)and x.classification='official')visible_source join public.games g on g.id=visible_source.game_id where not boss_private.games_can_view(actor,g))
 and not exists(select 1 from(select distinct(src->>'game_id')::uuid game_id from public.record_events re cross join lateral jsonb_array_elements(re.source_manifest->'sources')src where re.definition_id=d.id)visible_history join public.games historical on historical.id=visible_history.game_id where not boss_private.games_can_view(actor,historical)))
$$;
create function boss_private.ranking_authority_guard()returns trigger language plpgsql security definer set search_path=''as $$
begin
 -- Physical anchor update makes stale repeatable-read authority reads fail rather than authorize old rows.
 update public.people set updated_at=updated_at where id=coalesce(new.person_id,old.person_id);
 return coalesce(new,old);
end$$;
create trigger competition_access_guard before insert or update or delete on public.competition_access_assignments for each row execute function boss_private.ranking_authority_guard();
-- Bridge-only managers use the same physical revocation anchor as standard roles.
create function boss_private.ranking_catalog_guard()returns trigger language plpgsql security definer set search_path=''as $$
declare affected uuid[];begin
 if TG_TABLE_NAME='roles'then select array_agg(distinct a.person_id)into affected from public.competition_access_assignments a where a.role_id=coalesce(new.id,old.id);
 elsif TG_TABLE_NAME='role_permissions'then select array_agg(distinct a.person_id)into affected from public.competition_access_assignments a where a.role_id in(new.role_id,old.role_id);
 else select array_agg(distinct a.person_id)into affected from public.competition_access_assignments a join public.role_permissions rp on rp.role_id=a.role_id where rp.permission_id=coalesce(new.id,old.id);end if;
 perform 1 from public.people where id=any(affected)order by id for update;
 update public.people set updated_at=updated_at where id=any(affected);return coalesce(new,old);
end$$;
create trigger ranking_role_catalog_guard before update or delete on public.roles for each row execute function boss_private.ranking_catalog_guard();
create trigger ranking_role_permission_guard before insert or update or delete on public.role_permissions for each row execute function boss_private.ranking_catalog_guard();
create trigger ranking_permission_catalog_guard before update or delete on public.permissions for each row execute function boss_private.ranking_catalog_guard();
create function boss_private.ranking_validate_policy(c jsonb)returns boolean language plpgsql immutable set search_path=''as $$
declare r jsonb;k text;begin
 if c is null or not(c?&array['template','order_by','tie_weight','allow_ties','tiebreaks'])or jsonb_typeof(c)<>'object'or octet_length(c::text)>8192 or exists(select 1 from jsonb_object_keys(c)key_name where key_name<>all(array['template','order_by','win_points','tie_points','loss_points','tie_weight','allow_ties','tiebreaks','forfeit_score','allow_manual_resolution','mini_table_restart']))then return false;end if;
 if jsonb_typeof(c->'template')is distinct from'string'or jsonb_typeof(c->'order_by')is distinct from'string'or c->>'template'<>all(array['basketball','soccer','football','volleyball','baseball','softball'])or c->>'order_by'<>all(array['wins','win_percentage','points'])or jsonb_typeof(c->'tie_weight')is distinct from'number'or(c->>'tie_weight')::numeric not between 0 and 1 or jsonb_typeof(c->'allow_ties')is distinct from'boolean' then return false;end if;
 foreach k in array array['win_points','tie_points','loss_points']loop if c?k and(jsonb_typeof(c->k)is distinct from'number'or(c->>k)::numeric not between -1000 and 1000)then return false;end if;end loop;
 if c->>'order_by'='points'and not(c?&array['win_points','tie_points','loss_points'])then return false;end if;
 if c?'allow_manual_resolution'and jsonb_typeof(c->'allow_manual_resolution')is distinct from'boolean'or c?'mini_table_restart'and jsonb_typeof(c->'mini_table_restart')is distinct from'boolean'then return false;end if;
 if c?'forfeit_score'and(jsonb_typeof(c->'forfeit_score')is distinct from'array'or jsonb_array_length(c->'forfeit_score')<>2 or exists(select 1 from jsonb_array_elements(c->'forfeit_score')x where jsonb_typeof(x)<>'number'or(x#>>'{}')::numeric not between 0 and 1000000 or(x#>>'{}')::numeric<>trunc((x#>>'{}')::numeric)))then return false;end if;
 if jsonb_typeof(c->'tiebreaks')is distinct from'array'or jsonb_array_length(c->'tiebreaks')>12 then return false;end if;
 for r in select value from jsonb_array_elements(c->'tiebreaks')loop
 if jsonb_typeof(r->'type')is distinct from'string'or jsonb_typeof(r)<>'object'or exists(select 1 from jsonb_object_keys(r)key_name where key_name<>all(array['type','cap','minimum_meetings','group_id']))or r->>'type'<>all(array['head_to_head','head_to_head_percentage','mini_table','conference_percentage','division_percentage','common_opponents','differential','capped_differential','allowed','scoring_for','set_percentage','point_ratio','administrative','strength_of_schedule'])then return false;end if;
 if r->>'type'='capped_differential'and(jsonb_typeof(r->'cap')is distinct from'number'or(r->>'cap')::numeric not between 0 and 1000000)then return false;end if;
 if r?'minimum_meetings'and(jsonb_typeof(r->'minimum_meetings')is distinct from'number'or(r->>'minimum_meetings')::numeric not between 1 and 1000 or(r->>'minimum_meetings')::numeric<>trunc((r->>'minimum_meetings')::numeric))then return false;end if;
 if r?'group_id'and(jsonb_typeof(r->'group_id')is distinct from'string'or(r->>'group_id')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')then return false;end if;
 if r->>'type'='administrative'and not coalesce((c->>'allow_manual_resolution')::boolean,false)then return false;end if;
 end loop;return true;
exception when others then return false;end$$;
create function boss_private.ranking_validate_qualification(q jsonb,rate boolean)returns boolean language plpgsql immutable set search_path=''as $$
declare t jsonb;begin
 if q is null or jsonb_typeof(q)<>'object'or octet_length(q::text)>4096 or exists(select 1 from jsonb_object_keys(q)k where k<>'thresholds')then return false;end if;
 if not q?'thresholds'then return not rate;end if;
 if jsonb_typeof(q->'thresholds')is distinct from'array'or jsonb_array_length(q->'thresholds')>8 or(rate and jsonb_array_length(q->'thresholds')=0)then return false;end if;
 for t in select value from jsonb_array_elements(q->'thresholds')loop
 if not(t?&array['type','value'])or jsonb_typeof(t->'type')is distinct from'string'or jsonb_typeof(t)<>'object'or exists(select 1 from jsonb_object_keys(t)k where k<>all(array['type','value','metric']))or t->>'type'<>all(array['min_games','min_games_percentage','min_attempts','min_attempts_per_team_game','min_pa','min_pa_per_team_game','min_outs','min_innings_equivalent','min_minutes','min_attack_attempts','min_targets','min_receptions'])or jsonb_typeof(t->'value')is distinct from'number'or(t->>'value')::numeric not between 0.000001 and 1000000 then return false;end if;
 if t->>'type'='min_games_percentage'and(t->>'value')::numeric>100 then return false;end if;
 if t->>'type'in('min_attempts','min_attempts_per_team_game')and(jsonb_typeof(t->'metric')is distinct from'string'or(t->>'metric')!~'^[a-z][a-z0-9_]{0,63}$')then return false;end if;
 end loop;return true;
exception when others then return false;end$$;
create function boss_private.ranking_rate_keys(k text)returns text[]language sql immutable set search_path=''as $$
 select case k when'fg_percentage'then array['fgm','fga']when'three_point_percentage'then array['tpm','tpa']when'ft_percentage'then array['ftm','fta']when'two_point_percentage'then array['fgm','fga','tpm','tpa']when'shots_on_goal_rate'then array['shots_on_goal','shots']when'save_percentage'then array['saves','goals_allowed']when'completion_percentage'then array['passing_completions','passing_attempts']when'passing_yards_per_attempt'then array['passing_yards','passing_attempts']when'yards_per_carry'then array['rushing_yards','rush_attempts']when'yards_per_reception'then array['receiving_yards','receptions']when'punt_average'then array['punt_yards','punts']when'field_goal_percentage'then array['field_goals_made','field_goals_attempted']when'extra_point_percentage'then array['extra_points_made','extra_points_attempted']when'hitting_percentage'then array['kills','attack_errors','attack_attempts']when'avg'then array['hits','ab']when'obp'then array['hits','walks','hbp','ab','sacrifice_flies']when'slg'then array['singles','doubles','triples','home_runs','ab']when'ops'then array['hits','walks','hbp','ab','sacrifice_flies','singles','doubles','triples','home_runs']when'whip'then array['walks_allowed','hits_allowed','outs_pitched']when'era'then array['earned_runs','outs_pitched']when'strike_percentage'then array['strikes','pitches']else null::text[]end
$$;
create function boss_private.ranking_threshold_metric(t jsonb)returns text language sql immutable set search_path=''as $$
 select case t->>'type'when'min_attempts'then t->>'metric'when'min_attempts_per_team_game'then t->>'metric'when'min_pa'then'pa'when'min_pa_per_team_game'then'pa'when'min_outs'then'outs_pitched'when'min_innings_equivalent'then'outs_pitched'when'min_minutes'then'minutes'when'min_attack_attempts'then'attack_attempts'when'min_targets'then'targets'when'min_receptions'then'receptions'end
$$;
create function boss_private.ranking_latest_assignments(edition uuid)returns setof public.competition_game_assignments language sql stable security definer set search_path=''as $$
 select distinct on(game_id)a.*from public.competition_game_assignments a where edition_id=edition order by game_id,version desc
$$;
-- Internal composition: EXACTLY the Phase 6A reducers, no second statistical engine.
create function boss_private.ranking_compose(sport text,rows jsonb)returns jsonb language sql immutable set search_path=''as $$
 select jsonb_build_object('source_game_count',jsonb_array_length(rows),'confirmed_gp',(select count(*)from jsonb_array_elements(rows)r where coalesce((r->'participation'->>'confirmed')::boolean,false)),
 'metrics',boss_private.stat_reduce(rows),'rates',boss_private.stat_rates(sport,rows))
$$;
create function boss_private.ranking_measure(sport text,rows jsonb,metric text,kind text,qualification jsonb,allow_partial boolean,team_games integer)returns jsonb
language plpgsql immutable set search_path=''as $$
declare keys text[];joint jsonb;summary jsonb;v numeric;gp int;tracked int;all_n int:=jsonb_array_length(rows);t jsonb;actual numeric;minimum numeric;passed boolean:=true;why text:='qualified';threshold_results jsonb:='[]';begin
 keys:=case when kind='rate'then boss_private.ranking_rate_keys(metric)else array[metric]end;
 if keys is null then return jsonb_build_object('state','unqualified','value',null,'reason','unsupported_metric');end if;
 for t in select value from jsonb_array_elements(coalesce(qualification->'thresholds','[]'))loop
 if boss_private.ranking_threshold_metric(t)is not null then keys:=array_append(keys,boss_private.ranking_threshold_metric(t));end if;end loop;
 select coalesce(jsonb_agg(r order by r->>'game_id',r->>'id'),'[]')into joint from jsonb_array_elements(rows)r where not exists(select 1 from unnest(keys)k where r->'coverage'->>k is distinct from'tracked'or jsonb_typeof(r->'components'->k)is distinct from'number');
 tracked:=jsonb_array_length(joint);
 -- Project only the compared metric/qualification components into the existing
 -- Phase 6A reducers. Canonical manifests retain every source; no new formula.
 summary:=boss_private.ranking_compose(sport,(select coalesce(jsonb_agg(r||jsonb_build_object('components',(select coalesce(jsonb_object_agg(k,r->'components'->k),'{}')from unnest(keys)k where r->'components'?k),'coverage',(select coalesce(jsonb_object_agg(k,r->'coverage'->k),'{}')from unnest(keys)k where r->'coverage'?k))),'[]')from jsonb_array_elements(case when allow_partial and kind='count'then rows else joint end)r));
 gp:=(summary->>'confirmed_gp')::int;
 if kind='rate'then v:=(summary->'rates'->metric->>'value')::numeric;else v:=(summary->'metrics'->metric->>case when allow_partial then'observed_value'else'complete_value'end)::numeric;end if;
 if tracked<all_n and not allow_partial then why:='incomplete';elsif gp<1 then why:='unqualified';elsif v is null then why:='unqualified';end if;
 if kind='rate'and not boss_private.ranking_validate_qualification(qualification,true)then why:='no_policy';end if;
 for t in select value from jsonb_array_elements(coalesce(qualification->'thresholds','[]'))loop
 minimum:=(t->>'value')::numeric;
 if t->>'type'='min_games'then actual:=gp;
 elsif t->>'type'='min_games_percentage'then actual:=100*gp::numeric/nullif(team_games,0);
 else actual:=(summary->'metrics'->boss_private.ranking_threshold_metric(t)->>'complete_value')::numeric;
 if t->>'type'in('min_attempts_per_team_game','min_pa_per_team_game')then actual:=actual/nullif(team_games,0);elsif t->>'type'='min_innings_equivalent'then minimum:=ceil(minimum*3);end if;end if;
 passed:=passed and coalesce(actual>=minimum,false);threshold_results:=threshold_results||jsonb_build_array(jsonb_build_object('type',t->>'type','minimum',minimum,'actual',actual,'passed',coalesce(actual>=minimum,false)));
 end loop;
 if why='qualified'and not passed then why:='below_minimum';end if;
 return jsonb_build_object('state',why,'value',v,'summary',summary,'coverage',jsonb_build_object('complete_games',tracked,'source_games',all_n,'partial_allowed',allow_partial),'thresholds',threshold_results,'gp',gp);
end$$;
create function boss_private.ranking_dirty_edition(edition uuid)returns void language plpgsql security definer set search_path=''as $$
declare gen bigint;begin
 update public.competition_editions set generation=generation+1 where id=edition returning generation into gen;
 update public.ranking_scopes set target_generation=gen,state='pending',reason='source_or_policy_changed',build_cursor=null where edition_id=edition;
 insert into public.ranking_refresh_work(scope_id,target_generation)select id,gen from public.ranking_scopes where edition_id=edition on conflict(scope_id)do update set target_generation=excluded.target_generation,claimed_until=null;
end$$;
create function boss_private.ranking_source_changed()returns trigger language plpgsql security definer set search_path=''as $$
declare gid uuid:=coalesce(new.game_id,old.game_id);ed uuid;begin
 if TG_OP='UPDATE'and new.generation=old.generation and new.refreshed_generation=old.refreshed_generation and new.finalization_id is not distinct from old.finalization_id then return new;end if;
 for ed in select distinct e.id from public.competition_editions e where e.status='active'and(exists(select 1 from public.competition_game_assignments a where a.edition_id=e.id and a.game_id=gid)or exists(select 1 from public.ranking_definitions d join public.games g on g.id=gid where d.edition_id=e.id and d.status='active'and d.source_organization_id=g.organization_id and e.sport_key=g.sport_key and(d.team_id is null or d.team_id in(g.primary_team_id,g.opponent_team_id))and(d.season_id is null or d.season_id=g.season_id)))order by e.id loop perform boss_private.ranking_dirty_edition(ed);end loop;
 return coalesce(new,old);
end$$;
create constraint trigger ranking_stat_source_changed after insert or update or delete on public.stat_game_selections deferrable initially deferred for each row execute function boss_private.ranking_source_changed();
create function boss_private.ranking_metadata_changed()returns trigger language plpgsql security definer set search_path=''as $$begin perform boss_private.ranking_dirty_edition(coalesce(new.edition_id,old.edition_id));return coalesce(new,old);end$$;
do $$declare t text;f record;begin
 foreach t in array array['competition_groups','competition_entries','competition_entry_groups','standings_policy_revisions','competition_game_assignments','competition_game_assignment_groups','competition_rulings','ranking_definitions']loop execute format('create trigger %I after insert or update or delete on public.%I for each row execute function boss_private.ranking_metadata_changed()',t||'_dirty',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'ranking_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.sig);end loop;
end$$;

-- Canonical game/source locks precede these authority anchors; edition fences follow.
create function boss_private.ranking_lock_authority(actor uuid,edition uuid)returns void language plpgsql security definer set search_path=''as $$
declare orgs uuid[];begin
 select array_agg(distinct organization_id)into orgs from(
 select organization_id from public.competition_editions where id=edition union select source_organization_id from public.ranking_definitions where edition_id=edition union select team_organization_id from public.competition_entries where edition_id=edition)c;
 perform 1 from public.people where id=actor for share;
 perform 1 from public.role_assignments where person_id=actor and(scope_type='platform'or organization_id=any(orgs))order by id for share;
 perform 1 from public.organization_memberships where person_id=actor and organization_id=any(orgs)order by id for share;
 perform 1 from public.team_memberships where person_id=actor and organization_id=any(orgs)order by id for share;
 perform 1 from public.competition_access_assignments where person_id=actor and competition_id=(select competition_id from public.competition_editions where id=edition)order by id for share;
 perform 1 from public.organization_modules where organization_id=any(orgs)order by id for share;
 perform boss_private.games_require_live_auth();
end$$;
revoke all on function boss_private.ranking_lock_authority(uuid,uuid)from public,anon,authenticated,service_role;
