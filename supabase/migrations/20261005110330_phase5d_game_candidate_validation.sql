-- Phase 5D hosted blocker: preserve game.create security and align candidates.
-- No data, role, feature configuration, grants or engine mutation is changed.
create or replace function boss_private.games_read(q jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;org uuid;gameid uuid;team uuid;unit uuid;season uuid;child uuid;from_at timestamptz;to_at timestamptz;viewkey text;statuskey text;configuration_version bigint:=0;
 organizations jsonb:='[]';teams jsonb:='[]';units jsonb:='[]';seasons jsonb:='[]';sports jsonb;games jsonb:='[]';candidates jsonb:='[]';operators jsonb:='[]';features jsonb;cancreate boolean:=false;configure boolean:=false;g public.games;more boolean:=false;begin
 perform boss_private.games_require_live_auth();
 actor:=boss_private.require_admin_actor();
 perform boss_private.games_validate(q,array['view','from','to','organization_id','game_id','team_id','unit_id','season_id','status','child_person_id']);
 viewkey:=coalesce(q->>'view','all');statuskey:=q->>'status';from_at:=coalesce((q->>'from')::timestamptz,now()-interval '7 days');to_at:=coalesce((q->>'to')::timestamptz,now()+interval '28 days');
 if viewkey not in('all','family','navigation') or not isfinite(from_at) or not isfinite(to_at) or to_at<=from_at or to_at-from_at>interval '93 days' or(statuskey is not null and statuskey not in('scheduled','pregame','live','paused','delayed','suspended','final','canceled','postponed','abandoned')) then raise exception 'Invalid game query' using errcode='PT422';end if;
 org:=(q->>'organization_id')::uuid;gameid:=(q->>'game_id')::uuid;team:=(q->>'team_id')::uuid;unit:=(q->>'unit_id')::uuid;season:=(q->>'season_id')::uuid;child:=(q->>'child_person_id')::uuid;
 if child is not null and not boss_private.games_person_related(actor,child) then raise exception 'Access denied' using errcode='PT403';end if;
 if viewkey='navigation' then
 return jsonb_build_object('navigation_available',exists(select 1 from boss_private.games_organization_candidates(actor) candidate where boss_private.games_org_known(actor,candidate.organization_id) and(boss_private.games_role_permission(actor,'organization.manage',candidate.organization_id) or(boss_private.games_feature(candidate.organization_id,'game_center') and(boss_private.games_role_permission(actor,'games.view',candidate.organization_id) or exists(select 1 from public.teams t where t.organization_id=candidate.organization_id and(boss_private.games_role_permission(actor,'games.view',candidate.organization_id,t.id) or boss_private.games_team_related(actor,candidate.organization_id,t.id))))))));
 end if;
 if gameid is not null then select * into g from public.games where id=gameid;
 if not found then raise exception 'Access denied' using errcode='PT403';end if;features:=boss_private.games_configuration(g.organization_id);
 if not boss_private.games_can_view(actor,g,features) or(org is not null and org<>g.organization_id) then raise exception 'Access denied' using errcode='PT403';end if;org:=g.organization_id;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'label',o.name) order by o.name,o.id),'[]') into organizations
 from(select o.* from boss_private.games_organization_candidates(actor) candidate join public.organizations o on o.id=candidate.organization_id where boss_private.games_org_known(actor,o.id) order by o.name,o.id limit 100)o;
 if org is null then org:=(organizations->0->>'id')::uuid;end if;
 if org is not null and not boss_private.games_org_known(actor,org) then raise exception 'Access denied' using errcode='PT403';end if;
 features:=coalesce(features,boss_private.games_configuration(org));configure:=org is not null and boss_private.games_role_permission(actor,'organization.manage',org);
 select coalesce((select membership.version from public.organization_modules membership join public.modules catalog on catalog.id=membership.module_id and catalog.key='sports' and catalog.status='active'
 where membership.organization_id=org and membership.status='active' and membership.starts_at<=clock_timestamp() and(membership.ends_at is null or membership.ends_at>clock_timestamp()) order by membership.starts_at desc,membership.id desc limit 1),0) into configuration_version;
 select jsonb_agg(jsonb_build_object('key',key,'label',name) order by key) into sports from public.game_sports where status='active';
 if org is not null and boss_private.games_feature(org,'game_center',features) and boss_private.calendar_module_enabled(org) then
 if team is not null and not exists(select 1 from public.teams t where t.id=team and t.organization_id=org and(boss_private.games_role_permission(actor,'games.view',org,t.id) or boss_private.games_team_related(actor,org,t.id,child))) then raise exception 'Access denied' using errcode='PT403';end if;
 if unit is not null and not exists(select 1 from public.organization_units u where u.id=unit and u.organization_id=org and u.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
 if season is not null and not exists(select 1 from public.seasons s where s.id=season and s.organization_id=org) then raise exception 'Access denied' using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.name) order by t.name,t.id),'[]') into teams
 from(select * from public.teams t where t.organization_id=org and t.status='active' and(boss_private.games_role_permission(actor,'games.view',org,t.id) or boss_private.games_team_related(actor,org,t.id,child)) order by t.name,t.id limit 100)t;
 select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'label',u.name) order by u.name,u.id),'[]') into units
 from(select * from public.organization_units u where u.organization_id=org and u.status='active' and(boss_private.games_role_permission(actor,'games.view',org) or exists(select 1 from jsonb_array_elements(teams) t join public.teams tm on tm.id=(t->>'id')::uuid where tm.parent_unit_id=u.id)) order by u.name,u.id limit 100)u;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'label',s.name) order by s.name,s.id),'[]') into seasons
 from(select * from public.seasons s where s.organization_id=org and(boss_private.games_role_permission(actor,'games.view',org) or exists(select 1 from jsonb_array_elements(teams) t join public.teams tm on tm.id=(t->>'id')::uuid where tm.season_id=s.id)) order by s.name,s.id limit 100)s;
 with selected as materialized(select gg.* from public.games gg where gg.organization_id=org and(gameid is null or gg.id=gameid)
 and(gameid is not null or(gg.scheduled_start_at<to_at and gg.scheduled_end_at>from_at)) and(statuskey is null or gg.status=statuskey)
 and(team is null or team in(gg.primary_team_id,gg.opponent_team_id))
 and(unit is null or gg.parent_unit_id=unit or exists(select 1 from public.teams t where t.id=gg.opponent_team_id and t.parent_unit_id=unit))
 and(season is null or gg.season_id=season)
 and boss_private.games_can_view(actor,gg,features)
 and(viewkey<>'family' or boss_private.games_team_related(actor,org,gg.primary_team_id,child) or(gg.opponent_team_id is not null and boss_private.games_team_related(actor,org,gg.opponent_team_id,child)))
 and(child is null or boss_private.games_team_related(actor,org,gg.primary_team_id,child) or(gg.opponent_team_id is not null and boss_private.games_team_related(actor,org,gg.opponent_team_id,child)))
 order by gg.scheduled_start_at,gg.id limit 101)
 select coalesce(jsonb_agg(s.payload order by s.ordinal) filter(where s.ordinal<=100),'[]'),count(*)>100 into games,more
 from(select boss_private.games_projection(selected::public.games,actor,gameid is not null,viewkey='family',child,features) payload,row_number() over(order by scheduled_start_at,id) ordinal from selected)s;
 -- Creation expands only a bounded, indexed Calendar candidate set. Existing
 -- linked games are read from resolved schedule columns, never re-expanded.
 if viewkey='all' and gameid is null then
 with event_candidates as materialized(select e.* from public.events e where e.organization_id=org and e.event_type_key in('game','tournament') and e.status in('scheduled','confirmed')
 and e.start_at<to_at and(e.end_at>from_at or(e.recurrence is not null and e.recurrence_end_at>from_at))
 and boss_private.calendar_can_manage_event('events.manage',e.id) order by e.start_at,e.id limit 100),
 occurrences as(select e.id event_id,e.version event_version,e.recurrence,d.opponent_team_id,d.external_opponent_name,d.home_away,x.*
 from event_candidates e join public.event_game_details d on d.event_id=e.id and(d.opponent_team_id is not null or d.external_opponent_name is not null)
 cross join lateral boss_private.calendar_occurrences(e::public.events,from_at,to_at)x where x.status in('scheduled','confirmed')
 -- Match the existing game.create boundary: an internal opponent participates
 -- only when the same Calendar event explicitly targets that team.
 and (d.opponent_team_id is null or exists(select 1 from public.event_targets opponent_target
 where opponent_target.organization_id=e.organization_id and opponent_target.event_id=e.id
 and opponent_target.target_type='team' and opponent_target.target_id=d.opponent_team_id))
 and not exists(select 1 from public.games gg where gg.event_id=e.id and(gg.occurrence_mode='single' or gg.occurrence_key=x.occurrence_key))),
 projected as(select o.*,coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'label',t.name) order by t.name,t.id) from public.event_targets target join public.teams t on t.id=target.target_id and t.organization_id=org
 where target.event_id=o.event_id and target.target_type='team' and t.id is distinct from o.opponent_team_id and boss_private.games_role_permission(actor,'games.create',org,t.id)
 and(o.opponent_team_id is null or boss_private.games_role_permission(actor,'games.create',org,o.opponent_team_id))),'[]') choices from occurrences o order by o.start_at,o.event_id,o.occurrence_key limit 100)
 select coalesce(jsonb_agg(jsonb_build_object('event_id',event_id,'event_version',event_version,'occurrence_key',occurrence_key,'title',title,'start_at',start_at,'end_at',end_at,'home_away',home_away,'opponent_label',coalesce((select name from public.teams where id=opponent_team_id),external_opponent_name),'teams',choices) order by start_at,event_id,occurrence_key) filter(where jsonb_array_length(choices)>0),'[]') into candidates from projected;
 cancreate:=jsonb_array_length(candidates)>0;end if;
 if viewkey='all' and gameid is not null and boss_private.games_permission(actor,'games.manage',g,true,features) and boss_private.games_permission(actor,'games.operate',g,true,features) then
 select coalesce(jsonb_agg(candidate.payload order by candidate.person_id,candidate.role_id,candidate.team_id),'[]') into operators from(
 select a.person_id,a.id role_id,t.id team_id,jsonb_build_object('person_id',a.person_id,'display_name',coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Operator'),'role_assignment_id',a.id,'team_id',t.id,'functions',case when r.key='scorekeeper' then jsonb_build_array('scorekeeper') else jsonb_build_array('game_administrator') end) payload
 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active' join public.people p on p.id=a.person_id and p.status='active'
 join public.teams t on t.id in(g.primary_team_id,g.opponent_team_id)
 where a.status='active' and a.starts_at<=now() and(a.ends_at is null or a.ends_at>now()) and(a.organization_id=org or a.scope_type='platform')
 and boss_private.games_role_permission(a.person_id,'games.operate',org,t.id,a.id,features) and(r.key='scorekeeper' or boss_private.games_role_permission(a.person_id,'games.manage',org,t.id,a.id,features))
 order by a.person_id,a.id,t.id limit 100)candidate;
 end if;end if;
 return jsonb_build_object('navigation_available',org is not null and boss_private.games_feature(org,'game_center',features) and boss_private.calendar_module_enabled(org),'organization_id',org,'view',viewkey,'range',jsonb_build_object('from',from_at,'to',to_at),'features',features,'configuration_version',configuration_version,'capabilities',jsonb_build_object('configure',configure and viewkey='all','create',cancreate),'organizations',organizations,'teams',teams,'units',units,'seasons',seasons,'sports',sports,'games',games,'create_candidates',candidates,'operator_candidates',operators,'more',more);
exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT422' then raise;
 when others then raise exception 'Invalid game query' using errcode='PT422';end $$;
