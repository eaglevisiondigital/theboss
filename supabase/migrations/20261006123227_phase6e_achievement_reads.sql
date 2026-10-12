-- Bind the exact origin argument explicitly; unqualified team_id can resolve to a joined column.
create or replace function boss_private.athlete_staff_origin(actor uuid,k text,profile uuid,org uuid,team_id uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.athlete_profiles ap join public.team_memberships subject_membership on subject_membership.participant_id=ap.participant_id and subject_membership.person_id=ap.person_id
 join public.teams team on team.id=subject_membership.team_id and team.organization_id=subject_membership.organization_id and team.status='active'
 where ap.id=profile and ap.status='active'and team.id= $5 and team.organization_id=org and subject_membership.status='active'and subject_membership.starts_at<=clock_timestamp()and(subject_membership.ends_at is null or subject_membership.ends_at>clock_timestamp())
 and exists(select 1 from public.role_assignments assignment join public.roles role on role.id=assignment.role_id and role.status='active'
 join public.role_permissions rp on rp.role_id=role.id join public.permissions permission on permission.id=rp.permission_id and permission.key=k and permission.status='active'
 where assignment.person_id=actor and assignment.status='active'and assignment.starts_at<=clock_timestamp()and(assignment.ends_at is null or assignment.ends_at>clock_timestamp())and(
  assignment.scope_type='platform'and assignment.scope_id is null and assignment.organization_id is null
  or assignment.organization_id=org and(
   assignment.scope_type='organization'and assignment.scope_id=org and exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
   or assignment.scope_type='organization_unit'and assignment.scope_id=team.parent_unit_id and exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
   or assignment.scope_type='team'and assignment.scope_id= $5 and exists(select 1 from public.team_memberships m where m.team_id= $5 and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))))))
$$;

create function boss_private.achievement_live_state(r public.achievement_recognitions)returns text language plpgsql stable security definer set search_path=''as $$
declare rev public.achievement_definition_revisions;f jsonb;begin
 select *into rev from public.achievement_definition_revisions where id=r.definition_revision_id;
 if r.state='revoked'then return'revoked';end if;
 if rev.source_kind in('athlete_game','athlete_season','athlete_career','team_season')and boss_private.achievement_stat_pending(rev,r.organization_id)then return'processing';end if;
 if rev.source_kind='organization_decision'then return coalesce((select case when state='awarded'then'current'when state='revoked'then'revoked'else'unavailable'end from public.award_nominations where id=r.source_id),'unavailable');end if;
 if exists(select 1 from public.achievement_refresh_work w where w.definition_revision_id=rev.id and w.organization_id=r.organization_id and(w.state<>'current'or w.target_generation<>w.published_generation))then return case when exists(select 1 from public.achievement_refresh_work w where w.definition_revision_id=rev.id and w.organization_id=r.organization_id and w.state='unavailable')then'unavailable'else'processing'end;end if;
 select fact into f from boss_private.achievement_facts(rev,r.organization_id,null,1,r.subject_key,r.context_key)fact limit 1;
 if f is null or not coalesce((f->>'qualifies')::boolean,false)then return'corrected';end if;
 if f->>'source_hash'<>r.source_hash then return'processing';end if;
 return f->>'state';
end$$;
create function boss_private.achievement_can_view(actor uuid,r public.achievement_recognitions)returns boolean language plpgsql volatile security definer set search_path=''as $$
declare rev public.achievement_definition_revisions;begin
 select *into rev from public.achievement_definition_revisions where id=r.definition_revision_id;
 if r.profile_id is not null then
  if not boss_private.athlete_can_view(actor,r.profile_id)then return false;end if;
  if not(r.person_id=actor or boss_private.athlete_guardian(actor,r.person_id,false)or boss_private.athlete_staff_origin(actor,'athlete_profiles.view',r.profile_id,r.organization_id,r.team_id))then return false;end if;
 else
  if not(boss_private.games_role_permission(actor,'games.view',r.organization_id,r.team_id)or(r.team_id is not null and boss_private.games_team_related(actor,r.organization_id,r.team_id)))then return false;end if;
 end if;
 if rev.source_kind in('record','leaderboard')and not boss_private.ranking_can_definition(actor,case when rev.source_kind='record'then'records.view'else'leaderboard.view'end,rev.ranking_definition_id)then return false;end if;
 return true;
end$$;
create function boss_private.achievement_card(r public.achievement_recognitions)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare rev public.achievement_definition_revisions;s text;begin select *into rev from public.achievement_definition_revisions where id=r.definition_revision_id;s:=boss_private.achievement_live_state(r);
 return jsonb_build_object('id',r.id,'achievement_id',coalesce(r.athlete_achievement_id,r.entity_achievement_id),'profile_id',r.profile_id,'name',rev.name,'title',rev.name,'achievement_type',rev.category,'category',rev.category,'sport_key',r.sport_key,'subject_type',rev.subject_type,'team_id',r.team_id,'organization_id',r.organization_id,'season_id',r.season_id,'definition_revision',rev.revision,'verification_level',case when rev.source_kind='organization_decision'then'organization_verified'else'boss_verified'end,'source_type',r.source_type,'source_id',r.source_id,'source_generation',r.source_generation,'achieved_at',r.achieved_at,'achieved_on',r.achieved_at::date,'recognized_at',r.recognized_at,'state',s,'current',s='current','current_holder',s='current'and r.current_holder,'co_holder',s='current'and r.co_holder,'badge_icon',rev.badge_icon,'tier',rev.tier,'showcase_eligible',rev.showcase_eligible,'show_on_profile',coalesce((select show_on_profile from public.achievement_display_choices where athlete_achievement_id=r.athlete_achievement_id),true),'show_on_showcase',coalesce((select show_on_showcase from public.achievement_display_choices where athlete_achievement_id=r.athlete_achievement_id),false));
end$$;
create function boss_private.achievement_profile_cards(actor uuid,profile uuid,p_share boolean default false)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare response jsonb;begin
 select coalesce(jsonb_agg(card order by recognized_at desc,id),'[]')into response from(
  select r.id,r.recognized_at,boss_private.achievement_card(r)card from public.achievement_recognitions r join public.achievement_definition_revisions rev on rev.id=r.definition_revision_id
  left join public.achievement_display_choices choice on choice.athlete_achievement_id=r.athlete_achievement_id
  where r.profile_id=profile and(case when p_share then coalesce(choice.show_on_showcase,false)and rev.showcase_eligible and rev.source_kind not in('record','leaderboard')and boss_private.achievement_live_state(r)in('current','historical')else boss_private.achievement_can_view(actor,r)and coalesce(choice.show_on_profile,true)end)
  order by r.recognized_at desc,r.id limit 50
 )bounded;return response;
end$$;

-- Legacy Phase 6C canonical honors remain valid. New honors use the source-aware
-- sidecar; legacy private source origins are never given to transferred staff.
alter function boss_private.athlete_profile_projection(uuid,uuid)rename to athlete_profile_projection_phase6c;
create function boss_private.athlete_profile_projection(actor uuid,p_profile_id uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare result jsonb;legacy jsonb;begin
 result:=boss_private.athlete_profile_projection_phase6c(actor,p_profile_id);
 select coalesce(jsonb_agg(to_jsonb(a)-'actor_person_id'order by a.achieved_on desc nulls last,a.id),'[]')into legacy from(
  select aa.*from public.athlete_achievements aa join public.athlete_profiles p on p.id=aa.profile_id
  where aa.profile_id=p_profile_id and aa.definition_revision_id is null and(p.person_id=actor or boss_private.athlete_guardian(actor,p.person_id,false)or(aa.visibility<>'private'and aa.organization_id is not null and exists(select 1 from public.team_memberships tm where tm.participant_id=p.participant_id and tm.organization_id=aa.organization_id and tm.status='active'and tm.starts_at<=clock_timestamp()and(tm.ends_at is null or tm.ends_at>clock_timestamp())and boss_private.athlete_staff_origin(actor,'athlete_profiles.view',p.id,tm.organization_id,tm.team_id))))
  order by aa.achieved_on desc nulls last,aa.id limit 50
 )a;
 return jsonb_set(result,'{achievements}',boss_private.achievement_profile_cards(actor,p_profile_id)||legacy);
end$$;

alter function boss_recruiting_public.recruiting_showcase_read(text)rename to recruiting_showcase_read_phase6c;
create function boss_private.achievement_showcase_read(p_digest text)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare result jsonb;s public.recruiting_showcases;sr public.recruiting_showcase_revisions;cards jsonb;legacy jsonb;begin
 result:=boss_recruiting_public.recruiting_showcase_read_phase6c(p_digest);if result->>'available'<>'true'then return result;end if;
 select showcase.*into s from public.recruiting_showcases showcase join public.recruiting_share_links l on l.showcase_id=showcase.id where l.token_digest=p_digest and l.status='active';
 select *into sr from public.recruiting_showcase_revisions where id=s.published_revision_id;
 cards:='[]';legacy:='[]';
 if'achievements'=any(sr.visible_categories)or'records'=any(sr.visible_categories)then
  select coalesce(jsonb_agg(card-'profile_id'-'organization_id'-'team_id'-'source_id'-'source_generation'-'show_on_profile'-'show_on_showcase'order by card->>'recognized_at'desc),'[]')into cards from jsonb_array_elements(boss_private.achievement_profile_cards(null,s.profile_id,true))card
   where(cardinality(sr.sport_keys)=0 or card->>'sport_key'is null or card->>'sport_key'=any(sr.sport_keys))and(('records'=any(sr.visible_categories)and card->>'category'='record')or('achievements'=any(sr.visible_categories)and card->>'category'<>'record'));
  select coalesce(jsonb_agg(jsonb_build_object('title',a.title,'name',a.title,'sport_key',a.sport_key,'achieved_on',a.achieved_on,'verification_level',a.verification_level,'type',a.achievement_type,'current',true)order by a.achieved_on desc nulls last,a.id),'[]')into legacy from(select *from public.athlete_achievements aa where aa.profile_id=s.profile_id and aa.definition_revision_id is null and aa.visibility='showcase'and aa.source_record_event_id is null and aa.source_ranking_candidate_id is null and'achievements'=any(sr.visible_categories)and(cardinality(sr.sport_keys)=0 or aa.sport_key is null or aa.sport_key=any(sr.sport_keys))order by aa.achieved_on desc nulls last,aa.id limit 30)a;
 end if;
 return jsonb_set(result,'{achievements}',cards||legacy);
end$$;
create function boss_recruiting_public.recruiting_showcase_read(p_token_digest text)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.achievement_showcase_read(p_token_digest)$$;
revoke all on function boss_recruiting_public.recruiting_showcase_read_phase6c(text),boss_private.achievement_showcase_read(text),boss_recruiting_public.recruiting_showcase_read(text)from public,anon,authenticated,service_role;
grant execute on function boss_recruiting_public.recruiting_showcase_read(text)to anon,authenticated;

create function boss_private.achievement_read(q jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;org uuid;team uuid;profile uuid;after_id uuid;cards jsonb;definitions jsonb:='[]';nominations jsonb:='[]';history jsonb:='[]';catalog jsonb:='{}';manage boolean:=false;issue boolean:=false;approve boolean:=false;selected_rec public.achievement_recognitions;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(q,array['organization_id','team_id','profile_id','recognition_id','after_id'], '{}');org:=boss_private.athlete_uuid(q,'organization_id');team:=boss_private.athlete_uuid(q,'team_id');profile:=boss_private.athlete_uuid(q,'profile_id');after_id:=boss_private.athlete_uuid(q,'after_id');
 if profile is not null and not boss_private.athlete_can_view(actor,profile)then raise exception'Access denied'using errcode='PT403';end if;
 if org is not null then
  if team is not null and not exists(select 1 from public.teams where id=team and organization_id=org and status='active')then raise exception'Access denied'using errcode='PT403';end if;
  manage:=boss_private.achievement_permission(actor,'achievement_definitions.manage',org,team);issue:=boss_private.achievement_permission(actor,'awards.issue',org,team);approve:=boss_private.achievement_permission(actor,'awards.approve',org,team);
  if not(manage or issue or approve or boss_private.games_role_permission(actor,'games.view',org,team)or(team is not null and boss_private.games_team_related(actor,org,team)))then raise exception'Access denied'using errcode='PT403';end if;
  if manage then
   select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'owner_kind',d.owner_kind,'definition_key',d.definition_key,'status',d.status,'version',d.version,'revision',to_jsonb(rev)-'actor_person_id','freshness',coalesce(w.state,'unevaluated'),'has_more',w.state in('pending','processing'),'pending_revisions',coalesce((select jsonb_agg(jsonb_build_object('id',prior.id,'revision',prior.revision,'state',pw.state)order by prior.revision)from(select ar.*from public.achievement_definition_revisions ar join public.achievement_refresh_work aw on aw.definition_revision_id=ar.id and aw.organization_id=org where ar.definition_id=d.id and ar.id<>rev.id and aw.state<>'current'order by ar.revision limit 50)prior join public.achievement_refresh_work pw on pw.definition_revision_id=prior.id and pw.organization_id=org),'[]'))order by d.created_at desc,d.id),'[]')into definitions
   from(select *from public.achievement_definitions where(organization_id=org or owner_kind='boss')order by created_at desc,id limit 50)d join public.achievement_definition_revisions rev on rev.id=d.current_revision_id left join public.achievement_refresh_work w on w.definition_revision_id=rev.id and w.organization_id=org;
  end if;
  if manage or issue then
   catalog:=jsonb_build_object(
    'teams',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'season_id',t.season_id)order by t.name,t.id)from(select *from public.teams where organization_id=org and status='active'and(boss_private.achievement_permission(actor,'achievement_definitions.manage',org,id)or boss_private.achievement_permission(actor,'awards.issue',org,id))order by name,id limit 50)t),'[]'),
    'profiles',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',coalesce(pr.safe_fields->>'display_name','Athlete'))order by p.id)from(select distinct ap.*from public.athlete_profiles ap join public.team_memberships m on m.participant_id=ap.participant_id and m.person_id=ap.person_id where m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())and boss_private.athlete_can_view(actor,ap.id)order by ap.id limit 50)p left join public.athlete_profile_revisions pr on pr.id=p.current_revision_id),'[]'),
    'ranking_definitions',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'product',d.product,'sport_key',ed.sport_key,'subject_type',case when d.source_kind like'athlete_%'then'athlete'else'team'end)order by d.name,d.id)from(select *from public.ranking_definitions where source_organization_id=org and status='active'and boss_private.ranking_can_definition(actor,product||'.view',id)order by name,id limit 50)d join public.competition_editions ed on ed.id=d.edition_id),'[]'),
    'brackets',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'sport_key',e.sport_key)order by b.created_at desc,b.id)from(select tb.*from public.tournament_brackets tb join public.competition_editions ed on ed.id=tb.edition_id where ed.organization_id=org order by tb.created_at desc,tb.id limit 50)b join public.competition_editions e on e.id=b.edition_id),'[]'),
    'standings',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',e.name,'sport_key',e.sport_key)order by s.id)from(select rs.*from public.ranking_scopes rs join public.competition_editions ed on ed.id=rs.edition_id where ed.organization_id=org and rs.product='standings'and boss_private.ranking_can_edition(actor,'standings.view',rs.edition_id)order by rs.id limit 50)s join public.competition_editions e on e.id=s.edition_id),'[]'),
    'metrics',coalesce((select jsonb_agg(jsonb_build_object('key',m.key,'sport_key',m.sport_key)order by m.sport_key,m.key)from public.game_stat_catalog_items m where m.definition->>'classification'in('required','optional','derived','advanced')and boss_private.ranking_rate_keys(m.key)is null),'[]'));
  end if;
  if issue or approve then
   select coalesce(jsonb_agg(jsonb_build_object('id',n.id,'name',rev.name,'definition_id',rev.definition_id,'profile_id',n.profile_id,'team_id',n.team_id,'state',n.state,'version',n.version,'subject_type',n.subject_type,'achieved_at',n.achieved_at,'approval_required',rev.approval_required,'decisions',coalesce((select jsonb_agg(jsonb_build_object('decision',decision.decision,'version',decision.version,'private_note',decision.private_note,'created_at',decision.created_at)order by decision.version)from public.award_decisions decision where decision.nomination_id=n.id),'[]'))order by n.created_at desc,n.id),'[]')into nominations
   from(select *from public.award_nominations where organization_id=org and(team is null or team_id=team)and(boss_private.achievement_permission(actor,'awards.issue',organization_id,team_id)or boss_private.achievement_permission(actor,'awards.approve',organization_id,team_id))order by created_at desc,id limit 50)n join public.achievement_definition_revisions rev on rev.id=n.definition_revision_id;
  end if;
 end if;
 select coalesce(jsonb_agg(card order by id),'[]')into cards from(select r.id,boss_private.achievement_card(r)card from public.achievement_recognitions r where(org is not null or profile is not null or q?'recognition_id')and(not q?'recognition_id'or r.id=boss_private.athlete_uuid(q,'recognition_id'))and(org is null or r.organization_id=org)and(team is null or r.team_id=team)and(profile is null or r.profile_id=profile)and(after_id is null or r.id>after_id)and boss_private.achievement_can_view(actor,r)order by r.id limit 50)bounded;
 if q?'recognition_id'then
  select *into selected_rec from public.achievement_recognitions where id=boss_private.athlete_uuid(q,'recognition_id');if selected_rec.id is null or not boss_private.achievement_can_view(actor,selected_rec)then raise exception'Access denied'using errcode='PT403';end if;
  select coalesce(jsonb_agg(jsonb_build_object('event_type',h.event_type,'state',h.state,'version',h.version,'source_type',selected_rec.source_type,'source_generation',h.source_generation,'created_at',h.created_at)order by h.version desc),'[]')into history from(select *from public.achievement_history where recognition_id=selected_rec.id order by version desc limit 50)h;
 end if;
 return jsonb_build_object('contract','achievements-v1','recognitions',cards,'definitions',definitions,'nominations',nominations,'history',history,'catalog',catalog,'can_manage',manage,'can_issue',issue,'can_approve',approve,'next_cursor',case when jsonb_array_length(cards)=50 then cards->49->>'id'end);
end$$;
create function public.boss_achievement_read(p_query jsonb default'{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.achievement_read(p_query)$$;
revoke all on function boss_private.achievement_live_state(public.achievement_recognitions),boss_private.achievement_can_view(uuid,public.achievement_recognitions),boss_private.achievement_card(public.achievement_recognitions),boss_private.achievement_profile_cards(uuid,uuid,boolean),boss_private.athlete_profile_projection_phase6c(uuid,uuid),boss_private.athlete_profile_projection(uuid,uuid),boss_private.achievement_read(jsonb),public.boss_achievement_read(jsonb)from public,anon,authenticated,service_role;
grant execute on function boss_private.achievement_read(jsonb),public.boss_achievement_read(jsonb)to authenticated;

-- Low-volume recognition notifications reuse Phase 4A; never send private notes.
alter table public.notification_events drop constraint notification_events_source_type_check;
alter table public.notification_events add constraint notification_events_source_type_check check(source_type in('event','registration','registration_document','charge','payment','message','attendance_request','volunteer_shift','volunteer_assignment','volunteer_event','game_operation','tournament_advancement','achievement_history'));
insert into boss_private.notification_types(key,category,source_module,title,body)values
 ('achievement.recognized','events','sports','Achievement recognized','A verified recognition is available in your Boss achievements.'),
 ('achievement.corrected','events','sports','Achievement updated','An achievement was updated to match its authoritative source.');
create function boss_private.achievement_notification_visible(e public.notification_events,actor uuid)returns boolean language sql volatile security definer set search_path=''as $$select e.source_type='achievement_history'and e.source_module='sports'and boss_private.notification_person_active(actor)and exists(select 1 from public.achievement_history h join public.achievement_recognitions r on r.id=h.recognition_id where h.id=e.source_id and r.organization_id=e.organization_id and boss_private.achievement_can_view(actor,r))$$;
alter function boss_private.notification_source_visible(public.notification_events,uuid)rename to notification_source_visible_phase6d;
create function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid)returns boolean language plpgsql volatile security definer set search_path=''as $$begin if p_event.source_type='achievement_history'then return boss_private.achievement_notification_visible(p_event,p_person);end if;return boss_private.notification_source_visible_phase6d(p_event,p_person);end$$;
alter function boss_private.notification_candidates(public.notification_events,uuid,integer)rename to notification_candidates_phase6d;
create function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer)returns table(person_id uuid)language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type<>'achievement_history'then return query select *from boss_private.notification_candidates_phase6d(p_event,p_after,p_limit);return;end if;
 return query select candidate.person_id from(
  select r.person_id from public.achievement_history h join public.achievement_recognitions r on r.id=h.recognition_id where h.id=p_event.source_id and r.person_id is not null
  union select g.guardian_person_id from public.achievement_history h join public.achievement_recognitions r on r.id=h.recognition_id join public.guardian_relationships g on g.dependent_person_id=r.person_id where h.id=p_event.source_id and g.authority_status='active'and g.can_receive_communications and g.verified_at<=clock_timestamp()and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp())
 )candidate where(p_after is null or candidate.person_id>p_after)and boss_private.achievement_notification_visible(p_event,candidate.person_id)order by candidate.person_id limit p_limit;
end$$;
alter function boss_private.notification_contexts(public.notification_events,uuid)rename to notification_contexts_phase6d;
create function boss_private.notification_contexts(p_event public.notification_events,p_person uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin if p_event.source_type='achievement_history'then return jsonb_build_array(jsonb_build_object('kind','achievement','source_id',p_event.source_id));end if;return boss_private.notification_contexts_phase6d(p_event,p_person);end$$;
alter function boss_private.notification_destination(public.notification_events)rename to notification_destination_phase6d;
create function boss_private.notification_destination(p_event public.notification_events)returns text language plpgsql stable security definer set search_path=''as $$begin if p_event.source_type='achievement_history'then return'/app/achievements';end if;return boss_private.notification_destination_phase6d(p_event);end$$;
create function boss_private.achievement_notification_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$declare r public.achievement_recognitions;begin if new.event_type not in('recognized','corrected','revoked','restored')then return new;end if;select *into r from public.achievement_recognitions where id=new.recognition_id;perform boss_private.notification_enqueue('sports','achievement_history',new.id,r.organization_id,case when new.event_type in('corrected','revoked')then'achievement.corrected'else'achievement.recognized'end,new.version::text,jsonb_build_object('source_version',new.version));return new;end$$;
create trigger achievement_notification_source after insert on public.achievement_history for each row execute function boss_private.achievement_notification_ingest();
revoke all on function boss_private.achievement_notification_visible(public.notification_events,uuid),boss_private.notification_source_visible_phase6d(public.notification_events,uuid),boss_private.notification_source_visible(public.notification_events,uuid),boss_private.notification_candidates_phase6d(public.notification_events,uuid,integer),boss_private.notification_candidates(public.notification_events,uuid,integer),boss_private.notification_contexts_phase6d(public.notification_events,uuid),boss_private.notification_contexts(public.notification_events,uuid),boss_private.notification_destination_phase6d(public.notification_events),boss_private.notification_destination(public.notification_events),boss_private.achievement_notification_ingest()from public,anon,authenticated,service_role;
-- Phase 6C legacy rows remain historical truth; new ad-hoc issuance must not
-- bypass enabled definitions, nomination or approval policy.
alter function boss_private.athlete_mutate(jsonb)rename to athlete_mutate_phase6c;
create function boss_private.athlete_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin
 perform boss_private.games_require_live_auth();
 if command->>'action'='achievement.add'then raise exception'Use the enabled organization award workflow'using errcode='PT422';end if;
 return boss_private.athlete_mutate_phase6c(command);
end$$;
revoke all on function boss_private.athlete_mutate_phase6c(jsonb),boss_private.athlete_mutate(jsonb)from public,anon,authenticated,service_role;
grant execute on function boss_private.athlete_mutate(jsonb)to authenticated;
