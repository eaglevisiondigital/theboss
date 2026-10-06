-- Phase 6E manual decisions use their explicit award date, not automatic source activation timing.
-- Preserve automatic effective-date policy and all existing authority, ACL and immutable-history guards.
create or replace function boss_private.achievement_recognize(rev public.achievement_definition_revisions,org uuid,f jsonb,actor uuid)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare r public.achievement_recognitions;aid uuid;eid uuid;profile public.athlete_profiles;event text;achieved timestamptz:=coalesce((f->>'achieved_at')::timestamptz,clock_timestamp());begin
 select *into r from public.achievement_recognitions where definition_revision_id=rev.id and organization_id=org and subject_key=f->>'subject_key'and context_key=f->>'context_key'for update;
 if r.id is null then
  if not coalesce((f->>'qualifies')::boolean,false)or(rev.source_kind<>'organization_decision'and not rev.historical_evaluation and achieved<rev.effective_at)then return null;end if;
  if rev.subject_type='athlete'then
   select *into profile from public.athlete_profiles where id=(f->>'profile_id')::uuid and person_id=(f->>'person_id')::uuid and status='active';if profile.id is null then return null;end if;
   insert into public.athlete_achievements(profile_id,sport_key,achievement_type,title,achieved_on,season_id,organization_id,verification_level,visibility,source_record_event_id,source_ranking_candidate_id,actor_person_id,definition_revision_id)
   values(profile.id,rev.sport_key,case rev.category when'record'then'record'when'statistical_milestone'then'statistical_milestone'when'tournament'then'tournament_award'when'academic_character'then'academic_character'else'organization_award'end,rev.name,achieved::date,(f->>'season_id')::uuid,org,case when rev.source_kind='organization_decision'then'organization_verified'else'boss_verified'end,'private',case when f->>'source_type'='record_event'then(f->>'source_id')::uuid end,case when f->>'source_type'='ranking_candidate'then(f->>'source_id')::uuid end,actor,rev.id)returning id into aid;
  else
   insert into public.entity_achievements(subject_type,organization_id,team_id,definition_revision_id,title,achieved_at,verification_level,actor_person_id)
   values(rev.subject_type,org,(f->>'team_id')::uuid,rev.id,rev.name,achieved,case when rev.source_kind='organization_decision'then'organization_verified'else'boss_verified'end,actor)returning id into eid;
  end if;
  insert into public.achievement_recognitions(definition_revision_id,athlete_achievement_id,entity_achievement_id,profile_id,organization_id,team_id,person_id,season_id,sport_key,subject_key,context_key,source_type,source_id,source_generation,source_hash,source_manifest,state,current_holder,co_holder,achieved_at)
  values(rev.id,aid,eid,profile.id,org,(f->>'team_id')::uuid,profile.person_id,(f->>'season_id')::uuid,rev.sport_key,f->>'subject_key',f->>'context_key',f->>'source_type',(f->>'source_id')::uuid,(f->>'source_generation')::bigint,f->>'source_hash',f->'source_manifest',f->>'state',coalesce((f->>'holder')::boolean,false),coalesce((f->>'co_holder')::boolean,false),achieved)returning *into r;event:='recognized';
 else
  if r.source_hash=f->>'source_hash'and r.state=f->>'state'and r.current_holder=coalesce((f->>'holder')::boolean,false)and r.co_holder=coalesce((f->>'co_holder')::boolean,false)then return r.id;end if;
  event:=case when f->>'state'='revoked'then'revoked'when f->>'state'='corrected'then'corrected'when f->>'state'='historical'then'superseded'when r.state in('corrected','revoked','historical')then'restored'else'refreshed'end;
  update public.achievement_recognitions set source_id=(f->>'source_id')::uuid,source_generation=(f->>'source_generation')::bigint,source_hash=f->>'source_hash',source_manifest=f->'source_manifest',state=f->>'state',current_holder=coalesce((f->>'holder')::boolean,false),co_holder=coalesce((f->>'co_holder')::boolean,false),achieved_at=case when coalesce((f->>'qualifies')::boolean,false)then achieved else achieved_at end,version=version+1 where id=r.id returning *into r;
 end if;
 insert into public.achievement_history(recognition_id,version,event_type,state,source_generation,source_id,source_manifest,actor_person_id)values(r.id,r.version,event,r.state,r.source_generation,r.source_id,r.source_manifest||jsonb_build_object('achieved_at',r.achieved_at),actor);
 perform boss_private.athlete_audit(actor,'achievement.'||event,'achievement_recognition',r.id,coalesce(r.person_id,actor),null,jsonb_build_object('definition_revision_id',rev.id,'organization_id',org,'team_id',r.team_id,'source_type',r.source_type,'source_id',r.source_id,'generation',r.source_generation,'state',r.state));
 return r.id;
end$$;

create or replace function boss_private.achievement_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;request uuid;action text;i jsonb;hash text;receipt boss_private.achievement_operation_receipts;result jsonb;resource uuid;org uuid;team uuid;
 def public.achievement_definitions;rev public.achievement_definition_revisions;n public.award_nominations;decision public.award_decisions;r public.achievement_recognitions;p public.athlete_profiles;
 scope public.ranking_scopes;subject text;expected bigint;choice public.achievement_display_choices;f jsonb;note text;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);
 request:=boss_private.athlete_uuid(command,'request_id');action:=command->>'action';i:=command->'input';hash:=md5(command::text);
 perform pg_advisory_xact_lock(hashtextextended('boss-achievement-request:'||actor::text||':'||request::text,0));
 select *into receipt from boss_private.achievement_operation_receipts where actor_person_id=actor and request_id=request;
 -- Replays still pass the action's current resource authorization below.
 if receipt.actor_person_id is not null and receipt.input_hash<>hash then raise exception'Receipt conflict'using errcode='PT409';end if;
 if action in('definition.create','definition.revise','definition.set_status','definition.evaluate','definition.rebuild')then
  if action='definition.create'then
   perform boss_private.athlete_input(i,array['organization_id','owner_kind','definition_key','revision'],array['owner_kind','definition_key','revision']);org:=boss_private.athlete_uuid(i,'organization_id');
   if i->>'owner_kind'='boss'then
    if org is not null or not boss_private.achievement_platform_manager(actor)then raise exception'Platform definition authority required'using errcode='PT403';end if;
   else perform boss_private.achievement_authorize(actor,'achievement_definitions.manage',org);end if;
  else
   perform boss_private.athlete_input(i,array['definition_id','organization_id','expected_version','revision','status','revision_id'],array['definition_id']);
   select *into def from public.achievement_definitions where id=boss_private.athlete_uuid(i,'definition_id')for update;if def.id is null then raise exception'Access denied'using errcode='PT403';end if;
   org:=coalesce(def.organization_id,boss_private.athlete_uuid(i,'organization_id'));
   if def.owner_kind='boss'and action not in('definition.evaluate','definition.rebuild')then
    if not boss_private.achievement_platform_manager(actor)then raise exception'Platform definition authority required'using errcode='PT403';end if;
   else perform boss_private.achievement_authorize(actor,'achievement_definitions.manage',org);end if;
  end if;
  if receipt.actor_person_id is not null then return receipt.result||jsonb_build_object('replayed',true);end if;
  if action='definition.create'then
   insert into public.achievement_definitions(owner_kind,organization_id,definition_key,created_by_person_id)values(i->>'owner_kind',org,i->>'definition_key',actor)returning *into def;
   rev:=boss_private.achievement_revision(def,i->'revision',actor);update public.achievement_definitions set current_revision_id=rev.id where id=def.id;
  elsif action='definition.revise'then
   if(i->>'expected_version')::bigint is distinct from def.version then raise exception'Stale definition version'using errcode='PT409';end if;
   rev:=boss_private.achievement_revision(def,i->'revision',actor);update public.achievement_definitions set current_revision_id=rev.id,version=version+1 where id=def.id;
  elsif action='definition.set_status'then
   if(i->>'expected_version')::bigint is distinct from def.version or i->>'status'not in('active','inactive','archived')then raise exception'Stale or invalid definition state'using errcode='PT409';end if;
   update public.achievement_definitions set status=i->>'status',version=version+1 where id=def.id;update public.achievement_refresh_work set state=case when i->>'status'='active'then'pending'else'unavailable'end,cursor=null,target_generation=target_generation+1 where definition_revision_id in(select id from public.achievement_definition_revisions where definition_id=def.id);
  else
   if def.status<>'active'then raise exception'Definition inactive'using errcode='PT403';end if;
   select *into rev from public.achievement_definition_revisions where id=coalesce(boss_private.athlete_uuid(i,'revision_id'),def.current_revision_id)and definition_id=def.id;
   if rev.id is null then raise exception'Invalid definition revision'using errcode='PT403';end if;
   result:=boss_private.achievement_evaluate(rev,org,actor,action='definition.rebuild');
  end if;
  resource:=def.id;result:=coalesce(result,'{}')||jsonb_build_object('definition_id',def.id,'revision_id',coalesce(rev.id,def.current_revision_id),'organization_id',org);
 elsif action='standings.close'then
  perform boss_private.athlete_input(i,array['scope_id','reason'],array['scope_id','reason']);select *into scope from public.ranking_scopes where id=boss_private.athlete_uuid(i,'scope_id')for update;
  select organization_id into org from public.competition_editions where id=scope.edition_id;
  perform boss_private.achievement_authorize(actor,'achievement_definitions.manage',org);
  if not boss_private.ranking_can_edition(actor,'standings.manage',scope.edition_id)then raise exception'Access denied'using errcode='PT403';end if;
  if receipt.actor_person_id is not null then return receipt.result||jsonb_build_object('replayed',true);end if;
  if scope.product<>'standings'or scope.state<>'current'or scope.target_generation<>scope.published_generation or(scope.valid_until is not null and scope.valid_until<=clock_timestamp())or(select count(*)from public.standings_rows where scope_id=scope.id and rank=1)<>1 or exists(select 1 from boss_private.ranking_latest_assignments(scope.edition_id)a join public.games g on g.id=a.game_id where a.counts_for_standings and a.status='active'and(scope.group_id is null or a.group_id=scope.group_id)and g.status<>'final'and not exists(select 1 from public.competition_rulings ru where ru.assignment_id=a.id and ru.kind in('forfeit','result_override','vacated')))then raise exception'Current resolved completed standings required'using errcode='PT422';end if;
  insert into public.achievement_competition_closures(scope_id,generation,source_hash,champion_entry_id,reason,actor_person_id)values(scope.id,scope.published_generation,scope.source_hash,(select entry_id from public.standings_rows where scope_id=scope.id and rank=1),i->>'reason',actor)on conflict(scope_id,generation)do nothing;
  resource:=scope.id;result:=jsonb_build_object('scope_id',scope.id,'organization_id',org);
 elsif action in('award.nominate','award.approve','award.decline','award.withdraw','award.revoke','award.restore')then
  if action='award.nominate'then
   perform boss_private.athlete_input(i,array['definition_id','organization_id','team_id','season_id','profile_id','achieved_at','note'],array['definition_id','organization_id','achieved_at','note']);
   select *into def from public.achievement_definitions where id=boss_private.athlete_uuid(i,'definition_id')and status='active'for share;select *into rev from public.achievement_definition_revisions where id=def.current_revision_id;
   org:=boss_private.athlete_uuid(i,'organization_id');team:=boss_private.athlete_uuid(i,'team_id');
   if def.id is null or rev.source_kind<>'organization_decision'or(def.organization_id is not null and def.organization_id<>org)or(rev.team_id is not null and rev.team_id is distinct from team)or(rev.season_id is not null and rev.season_id is distinct from boss_private.athlete_uuid(i,'season_id'))then raise exception'Invalid award definition context'using errcode='PT422';end if;
   perform boss_private.achievement_authorize(actor,'awards.issue',org,team,boss_private.athlete_uuid(i,'profile_id'));
   if rev.subject_type='athlete'then
    select *into p from public.athlete_profiles where id=boss_private.athlete_uuid(i,'profile_id')and status='active'for share;
    if p.id is null or team is null or not exists(select 1 from public.team_memberships m where m.organization_id=org and m.team_id=team and m.participant_id=p.participant_id and m.person_id=p.person_id and m.starts_at<=(i->>'achieved_at')::timestamptz and(m.ends_at is null or m.ends_at>(i->>'achieved_at')::timestamptz)and m.status='active')then raise exception'Legitimate scoped athlete relationship required'using errcode='PT403';end if;
    subject:=p.person_id::text;
   elsif rev.subject_type='team'then subject:=team::text;if team is null then raise exception'Team required'using errcode='PT422';end if;
   else if team is not null then raise exception'Invalid organization recipient'using errcode='PT422';end if;subject:=org::text;end if;
  else
   perform boss_private.athlete_input(i,array['nomination_id','expected_version','note'],array['nomination_id','expected_version','note']);select *into n from public.award_nominations where id=boss_private.athlete_uuid(i,'nomination_id')for update;
   if n.id is null then raise exception'Access denied'using errcode='PT403';end if;org:=n.organization_id;team:=n.team_id;select *into rev from public.achievement_definition_revisions where id=n.definition_revision_id;
   perform boss_private.achievement_authorize(actor,case when action='award.withdraw'then'awards.issue'else'awards.approve'end,org,team,n.profile_id);
  end if;
  if receipt.actor_person_id is not null then return receipt.result||jsonb_build_object('replayed',true);end if;
  note:=i->>'note';if length(btrim(note))not between 1 and 500 then raise exception'Award decision note required'using errcode='PT422';end if;
  if action='award.nominate'then
   insert into public.award_nominations(definition_revision_id,organization_id,team_id,season_id,profile_id,subject_type,subject_key,achieved_at,nominated_by_person_id)
   values(rev.id,org,team,boss_private.athlete_uuid(i,'season_id'),p.id,rev.subject_type,subject,(i->>'achieved_at')::timestamptz,actor)returning *into n;
   insert into public.award_decisions(nomination_id,version,decision,private_note,actor_person_id)values(n.id,1,'nominated',note,actor)returning *into decision;
   if not rev.approval_required then action:='award.approve';end if;
  else
   if(i->>'expected_version')::bigint is distinct from n.version then raise exception'Stale award version'using errcode='PT409';end if;
  end if;
  if action<>'award.nominate'then
   if(action='award.approve'and n.state<>'nominated')or(action='award.restore'and n.state<>'revoked')or(action='award.revoke'and n.state<>'awarded')or(action in('award.decline','award.withdraw')and n.state<>'nominated')then raise exception'Invalid award transition'using errcode='PT409';end if;
   if action='award.withdraw'and n.nominated_by_person_id<>actor then raise exception'Only issuer may withdraw nomination'using errcode='PT403';end if;
   update public.award_nominations set state=case action when'award.approve'then'awarded'when'award.restore'then'awarded'when'award.revoke'then'revoked'when'award.decline'then'declined'else'withdrawn'end,version=version+1 where id=n.id returning *into n;
   insert into public.award_decisions(nomination_id,version,decision,private_note,actor_person_id)values(n.id,n.version,case action when'award.approve'then'approved'when'award.restore'then'restored'when'award.revoke'then'revoked'when'award.decline'then'declined'else'withdrawn'end,note,actor)returning *into decision;
   if n.state in('awarded','revoked')then
    select *into p from public.athlete_profiles where id=n.profile_id;
    f:=jsonb_build_object('subject_key',n.subject_key,'context_key',n.id::text,'profile_id',p.id,'person_id',p.person_id,'team_id',n.team_id,'season_id',n.season_id,'source_type','organization_decision','source_id',n.id,'source_generation',n.version,'source_hash',md5(decision.id::text),'source_manifest',jsonb_build_object('nomination_id',n.id,'decision_id',decision.id,'decision_version',n.version,'issuer_person_id',actor),'state',case when n.state='awarded'then'current'else'revoked'end,'achieved_at',n.achieved_at,'qualifies',n.state='awarded');
    resource:=boss_private.achievement_recognize(rev,org,f,actor);if resource is null then raise exception'Award recipient is no longer available'using errcode='PT409';end if;update public.award_nominations set recognition_id=resource where id=n.id;
   end if;
  end if;
  resource:=n.id;result:=jsonb_build_object('nomination_id',n.id,'recognition_id',n.recognition_id,'organization_id',org,'version',n.version,'state',n.state);
 elsif action='display.set'then
  perform boss_private.athlete_input(i,array['achievement_id','show_on_profile','show_on_showcase'],array['achievement_id','show_on_profile','show_on_showcase']);
  select ap.*into p from public.athlete_profiles ap join public.athlete_achievements aa on aa.profile_id=ap.id where aa.id=boss_private.athlete_uuid(i,'achievement_id')for share of ap;
  perform 1 from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=p.person_id order by id for share;
  if p.id is null or not boss_private.athlete_guardian(actor,p.person_id,true)then raise exception'Current guardian profile authority required'using errcode='PT403';end if;
  select *into r from public.achievement_recognitions where athlete_achievement_id=boss_private.athlete_uuid(i,'achievement_id')for update;
  if r.id is not null then select *into rev from public.achievement_definition_revisions where id=r.definition_revision_id;end if;
  if(i->>'show_on_showcase')::boolean and(r.id is null or not rev.showcase_eligible or rev.source_kind in('record','leaderboard')or r.state not in('current','historical'))then raise exception'Achievement not eligible for showcase'using errcode='PT403';end if;
  if receipt.actor_person_id is not null then return receipt.result||jsonb_build_object('replayed',true);end if;
  insert into public.achievement_display_choices(profile_id,athlete_achievement_id,show_on_profile,show_on_showcase,actor_person_id)values(p.id,boss_private.athlete_uuid(i,'achievement_id'),(i->>'show_on_profile')::boolean,(i->>'show_on_showcase')::boolean,actor)on conflict(athlete_achievement_id)do update set show_on_profile=excluded.show_on_profile,show_on_showcase=excluded.show_on_showcase,actor_person_id=actor,updated_at=clock_timestamp();
  if r.id is not null then update public.achievement_recognitions set version=version+1 where id=r.id returning *into r;insert into public.achievement_history(recognition_id,version,event_type,state,source_generation,source_id,source_manifest,actor_person_id)values(r.id,r.version,case when(i->>'show_on_showcase')::boolean then'published'else'hidden'end,r.state,r.source_generation,r.source_id,r.source_manifest,actor);end if;
  resource:=boss_private.athlete_uuid(i,'achievement_id');result:=jsonb_build_object('profile_id',p.id);
 else raise exception'Unsupported achievement action'using errcode='PT422';end if;
 result:=coalesce(result,'{}')||jsonb_build_object('contract','achievements-v1','action',command->>'action','id',resource);
 insert into boss_private.achievement_operation_receipts(actor_person_id,request_id,input_hash,result)values(actor,request,hash,result);
 return result||jsonb_build_object('replayed',false);
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or check_violation or not_null_violation then raise exception'Invalid achievement value'using errcode='PT422';when unique_violation then raise exception'Duplicate recognition or decision'using errcode='PT409';end$$;
