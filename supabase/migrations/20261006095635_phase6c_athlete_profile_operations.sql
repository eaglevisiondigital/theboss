-- Phase 6C caller-bound policy and transactional mutation API.
create function boss_private.athlete_uuid(i jsonb,k text)returns uuid language plpgsql immutable set search_path=''as $$
begin if not i?k then return null;end if;if jsonb_typeof(i->k)is distinct from'string'then raise exception'Invalid resource identifier'using errcode='PT422';end if;return(i->>k)::uuid;
exception when invalid_text_representation then raise exception'Invalid resource identifier'using errcode='PT422';end$$;

create function boss_private.athlete_input(i jsonb,allowed text[],required text[]default'{}')returns void language plpgsql immutable set search_path=''as $$
begin if i is null or jsonb_typeof(i)is distinct from'object'or octet_length(i::text)>32768 or not(i?&required)or exists(select 1 from jsonb_object_keys(i)k where k<>all(allowed))or exists(select 1 from jsonb_each(i)e where jsonb_typeof(e.value)='null')then raise exception'Invalid athlete-profile input'using errcode='PT422';end if;end$$;

create function boss_private.athlete_safe_fields(i jsonb)returns boolean language sql immutable set search_path=''as $$
 select jsonb_typeof(i)='object'and octet_length(i::text)<=8192
 and not exists(select 1 from jsonb_object_keys(i)k where k<>all(array['display_name','positions','jersey_numbers','class_year','city_state','bio','goals','handedness']))
 and(not i?'display_name'or jsonb_typeof(i->'display_name')='string'and length(btrim(i->>'display_name'))between 1 and 100)
 and(not i?'bio'or jsonb_typeof(i->'bio')='string'and length(i->>'bio')<=1200)
 and(not i?'goals'or jsonb_typeof(i->'goals')='string'and length(i->>'goals')<=800)
 and(not i?'city_state'or jsonb_typeof(i->'city_state')='string'and length(i->>'city_state')<=100)
 and(not i?'class_year'or jsonb_typeof(i->'class_year')='number'and(i->>'class_year')::numeric between 1900 and 2200)
 and(not i?'handedness'or jsonb_typeof(i->'handedness')='string'and i->>'handedness'=any(array['right','left','both']))
 and(not i?'positions'or jsonb_typeof(i->'positions')='array'and jsonb_array_length(i->'positions')<=12 and not exists(select 1 from jsonb_array_elements(i->'positions')x where jsonb_typeof(x)<>'string'or length(x#>>'{}')not between 1 and 60))
 and(not i?'jersey_numbers'or jsonb_typeof(i->'jersey_numbers')='array'and jsonb_array_length(i->'jersey_numbers')<=12 and not exists(select 1 from jsonb_array_elements(i->'jersey_numbers')x where jsonb_typeof(x)<>'string'or length(x#>>'{}')not between 1 and 12))
$$;

create function boss_private.athlete_guardian(actor uuid,subject uuid,manage boolean default false)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.guardian_relationships g where g.guardian_person_id=actor and g.dependent_person_id=subject and g.authority_status='active'
 and g.verified_at<=clock_timestamp()and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp())and(not manage or g.can_manage_profile))
$$;

create function boss_private.athlete_staff(actor uuid,k text,profile uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select k=any(array['athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish'])
 and exists(select 1 from public.athlete_profiles ap join public.team_memberships subject_membership on subject_membership.participant_id=ap.participant_id and subject_membership.person_id=ap.person_id
 join public.teams team on team.id=subject_membership.team_id and team.organization_id=subject_membership.organization_id and team.status='active'
 where ap.id=profile and ap.status='active'and subject_membership.status='active'and subject_membership.starts_at<=clock_timestamp()and(subject_membership.ends_at is null or subject_membership.ends_at>clock_timestamp())
 and exists(select 1 from public.role_assignments assignment join public.roles role on role.id=assignment.role_id and role.status='active'
 join public.role_permissions rp on rp.role_id=role.id join public.permissions permission on permission.id=rp.permission_id and permission.key=k and permission.status='active'
 where assignment.person_id=actor and assignment.status='active'and assignment.starts_at<=clock_timestamp()and(assignment.ends_at is null or assignment.ends_at>clock_timestamp())and(
  assignment.scope_type='platform'and assignment.scope_id is null and assignment.organization_id is null
  or assignment.organization_id=team.organization_id and(
   assignment.scope_type='organization'and assignment.scope_id=team.organization_id and exists(select 1 from public.organization_memberships m where m.organization_id=team.organization_id and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
   or assignment.scope_type='organization_unit'and assignment.scope_id=team.parent_unit_id and exists(select 1 from public.organization_memberships m where m.organization_id=team.organization_id and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
   or assignment.scope_type='team'and assignment.scope_id=team.id and exists(select 1 from public.team_memberships m where m.team_id=team.id and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))))))
$$;

create function boss_private.athlete_can_view(actor uuid,profile uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.athlete_profiles p where p.id=profile and p.status='active'and(p.person_id=actor or boss_private.athlete_guardian(actor,p.person_id,false)or boss_private.athlete_staff(actor,'athlete_profiles.view',p.id)))
$$;
create function boss_private.athlete_can_manage(actor uuid,profile uuid)returns boolean language sql volatile security definer set search_path=''as $$
 -- Self-publication is intentionally closed until an approved adult-policy fact exists.
 select exists(select 1 from public.athlete_profiles p where p.id=profile and p.status='active'and(boss_private.athlete_guardian(actor,p.person_id,true)or boss_private.athlete_staff(actor,'athlete_profiles.manage',p.id)))
$$;
create function boss_private.athlete_can_showcase(actor uuid,profile uuid,k text)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.athlete_profiles p where p.id=profile and p.status='active'and(boss_private.athlete_guardian(actor,p.person_id,true)or boss_private.athlete_staff(actor,k,p.id)))
$$;

create function boss_private.athlete_audit(actor uuid,action text,typ text,rid uuid,subject uuid,request uuid,details jsonb default '{}')returns void language sql volatile security definer set search_path=''as $$
 insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(actor,auth.uid(),action,typ,rid,'person',subject,request,coalesce(details,'{}'))
$$;

create function boss_private.athlete_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;request uuid;i jsonb;action text;input_hash text;receipt boss_private.athlete_profile_operation_receipts;result jsonb;
 p public.athlete_profiles;s public.recruiting_showcases;r public.athlete_profile_revisions;sr public.recruiting_showcase_revisions;c public.recruiting_consents;
 participant public.participants;resource uuid;expected bigint;org uuid;team uuid;subject uuid;categories text[];sports text[];metrics text[];rev bigint;
begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);
 if jsonb_typeof(command->'action')is distinct from'string'or jsonb_typeof(command->'input')is distinct from'object'then raise exception'Invalid athlete-profile command'using errcode='PT422';end if;
 request:=boss_private.athlete_uuid(command,'request_id');i:=command->'input';action:=command->>'action';input_hash:=md5(command::text);
 perform pg_advisory_xact_lock(hashtextextended('boss-athlete-request:'||actor::text||':'||request::text,0));
 select *into receipt from boss_private.athlete_profile_operation_receipts where actor_person_id=actor and request_id=request;
 if receipt.actor_person_id is not null then
  if receipt.input_hash<>input_hash then raise exception'Receipt conflict'using errcode='PT409';end if;
  if receipt.result?'profile_id'and not boss_private.athlete_can_view(actor,boss_private.athlete_uuid(receipt.result,'profile_id'))then raise exception'Access denied'using errcode='PT403';end if;
  return receipt.result||jsonb_build_object('replayed',true);
 end if;

 if action='profile.create'then
  perform boss_private.athlete_input(i,array['participant_id','visibility','safe_fields'],array['participant_id','safe_fields']);
  select *into participant from public.participants where id=boss_private.athlete_uuid(i,'participant_id')and status='active'for share;
  if participant.id is null then raise exception'Participant not found'using errcode='PT404';end if;
  perform pg_advisory_xact_lock(hashtextextended('boss-athlete-profile:'||participant.id::text,0));
  select *into p from public.athlete_profiles where participant_id=participant.id for update;
  if p.id is null then
   if not(boss_private.athlete_guardian(actor,participant.person_id,true)or exists(select 1 from public.team_memberships membership join public.teams team on team.id=membership.team_id and team.organization_id=membership.organization_id and team.status='active'where membership.participant_id=participant.id and membership.person_id=participant.person_id and membership.status='active'and membership.starts_at<=clock_timestamp()and(membership.ends_at is null or membership.ends_at>clock_timestamp())and boss_private.has_permission('athlete_profiles.manage',team.organization_id,team.parent_unit_id,team.id)))then raise exception'Access denied'using errcode='PT403';end if;
   if not boss_private.athlete_safe_fields(i->'safe_fields')then raise exception'Invalid safe profile fields'using errcode='PT422';end if;
   insert into public.athlete_profiles(participant_id,person_id,visibility,created_by_person_id)values(participant.id,participant.person_id,coalesce(i->>'visibility','private'),actor)returning *into p;
   insert into public.athlete_profile_revisions(profile_id,revision,entered_by,safe_fields,actor_person_id)values(p.id,1,case when actor=participant.person_id then'athlete'when boss_private.athlete_guardian(actor,participant.person_id,false)then'guardian'else'administrator'end,i->'safe_fields',actor)returning *into r;
   update public.athlete_profiles set current_revision_id=r.id,updated_at=clock_timestamp()where id=p.id;perform boss_private.athlete_audit(actor,'athlete_profile.create','athlete_profile',p.id,p.person_id,request,jsonb_build_object('revision_id',r.id));
  elsif not boss_private.athlete_can_view(actor,p.id)then raise exception'Access denied'using errcode='PT403';end if;
  result:=jsonb_build_object('profile_id',p.id,'participant_id',p.participant_id,'person_id',p.person_id,'version',p.version);

 elsif action='profile.revise'then
  perform boss_private.athlete_input(i,array['profile_id','expected_version','visibility','safe_fields'],array['profile_id','expected_version','safe_fields']);
  select *into p from public.athlete_profiles where id=boss_private.athlete_uuid(i,'profile_id')for update;
  if p.id is null then raise exception'Profile not found'using errcode='PT404';end if;perform 1 from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=p.person_id order by id for share;
  if not boss_private.athlete_can_manage(actor,p.id)then raise exception'Access denied'using errcode='PT403';end if;
  expected:=(i->>'expected_version')::bigint;if expected<>p.version then raise exception'Stale profile version'using errcode='PT409';end if;
  if not boss_private.athlete_safe_fields(i->'safe_fields')then raise exception'Invalid safe profile fields'using errcode='PT422';end if;
  select coalesce(max(revision),0)+1 into rev from public.athlete_profile_revisions where profile_id=p.id;
  insert into public.athlete_profile_revisions(profile_id,revision,entered_by,safe_fields,actor_person_id)values(p.id,rev,case when boss_private.athlete_guardian(actor,p.person_id,false)then'guardian'else'administrator'end,i->'safe_fields',actor)returning *into r;
  update public.athlete_profiles set current_revision_id=r.id,visibility=coalesce(i->>'visibility',visibility),version=version+1,updated_at=clock_timestamp()where id=p.id returning *into p;
  perform boss_private.athlete_audit(actor,'athlete_profile.revise','athlete_profile',p.id,p.person_id,request,jsonb_build_object('revision_id',r.id,'version',p.version));result:=jsonb_build_object('profile_id',p.id,'revision_id',r.id,'version',p.version);

 elsif action='measurable.add'then
  perform boss_private.athlete_input(i,array['profile_id','sport_key','metric_key','value','unit','measured_on','provenance','visibility','organization_id','team_id','source_label'],array['profile_id','sport_key','metric_key','value','unit','measured_on','provenance','visibility']);
  select *into p from public.athlete_profiles where id=boss_private.athlete_uuid(i,'profile_id')for share;if p.id is null then raise exception'Profile not found'using errcode='PT404';end if;
  if(i->>'provenance')in('coach_verified','organization_verified','event_verified')then if not boss_private.athlete_staff(actor,'athlete_profiles.verify',p.id)then raise exception'Verification authority required'using errcode='PT403';end if;
  elsif not boss_private.athlete_can_manage(actor,p.id)then raise exception'Access denied'using errcode='PT403';end if;
  org:=boss_private.athlete_uuid(i,'organization_id');team:=boss_private.athlete_uuid(i,'team_id');
  insert into public.athlete_measurables(profile_id,sport_key,metric_key,value,unit,measured_on,provenance,verification_state,visibility,organization_id,team_id,source_label,actor_person_id)
  values(p.id,i->>'sport_key',i->>'metric_key',(i->>'value')::numeric,i->>'unit',(i->>'measured_on')::date,i->>'provenance',case when i->>'provenance'in('coach_verified','organization_verified','event_verified')then'verified'else'unverified'end,i->>'visibility',org,team,i->>'source_label',actor)returning id into resource;
  perform boss_private.athlete_audit(actor,'athlete_profile.measurable_add','athlete_measurable',resource,p.person_id,request,jsonb_build_object('profile_id',p.id,'provenance',i->>'provenance'));result:=jsonb_build_object('profile_id',p.id,'measurable_id',resource);

 elsif action='achievement.add'then
  perform boss_private.athlete_input(i,array['profile_id','sport_key','achievement_type','title','achieved_on','season_id','organization_id','visibility','source_record_event_id','source_ranking_candidate_id'],array['profile_id','achievement_type','title','visibility']);
  select *into p from public.athlete_profiles where id=boss_private.athlete_uuid(i,'profile_id')for share;if p.id is null then raise exception'Profile not found'using errcode='PT404';end if;
  if not boss_private.athlete_staff(actor,'athlete_profiles.verify',p.id)then raise exception'Access denied'using errcode='PT403';end if;
  if i?'source_record_event_id'and not exists(select 1 from public.record_events e join public.ranking_candidates candidate on candidate.scope_id=e.scope_id and candidate.subject_key=e.subject_key where e.id=boss_private.athlete_uuid(i,'source_record_event_id')and candidate.person_id=p.person_id)then raise exception'Invalid record source'using errcode='PT422';end if;
  if i?'source_ranking_candidate_id'and not exists(select 1 from public.ranking_candidates candidate where candidate.id=boss_private.athlete_uuid(i,'source_ranking_candidate_id')and candidate.person_id=p.person_id)then raise exception'Invalid ranking source'using errcode='PT422';end if;
  insert into public.athlete_achievements(profile_id,sport_key,achievement_type,title,achieved_on,season_id,organization_id,verification_level,visibility,source_record_event_id,source_ranking_candidate_id,actor_person_id)
  values(p.id,i->>'sport_key',i->>'achievement_type',i->>'title',(i->>'achieved_on')::date,boss_private.athlete_uuid(i,'season_id'),boss_private.athlete_uuid(i,'organization_id'),case when i?'source_record_event_id'or i?'source_ranking_candidate_id'then'boss_verified'else'organization_verified'end,i->>'visibility',boss_private.athlete_uuid(i,'source_record_event_id'),boss_private.athlete_uuid(i,'source_ranking_candidate_id'),actor)returning id into resource;
  perform boss_private.athlete_audit(actor,'athlete_profile.achievement_add','athlete_achievement',resource,p.person_id,request,jsonb_build_object('profile_id',p.id,'verification','organization_verified'));result:=jsonb_build_object('profile_id',p.id,'achievement_id',resource);

 elsif action='media.add'then
  perform boss_private.athlete_input(i,array['profile_id','sport_key','media_type','url','title','source','rights_state','visibility'],array['profile_id','media_type','url','title','source','rights_state','visibility']);
  select *into p from public.athlete_profiles where id=boss_private.athlete_uuid(i,'profile_id')for share;if not boss_private.athlete_can_manage(actor,p.id)then raise exception'Access denied'using errcode='PT403';end if;
  insert into public.athlete_media_links(profile_id,sport_key,media_type,url,title,source,rights_state,visibility,actor_person_id)values(p.id,i->>'sport_key',i->>'media_type',i->>'url',i->>'title',i->>'source',i->>'rights_state',i->>'visibility',actor)returning id into resource;
  perform boss_private.athlete_audit(actor,'athlete_profile.media_add','athlete_media_link',resource,p.person_id,request,jsonb_build_object('profile_id',p.id,'rights_state',i->>'rights_state'));result:=jsonb_build_object('profile_id',p.id,'media_id',resource);

 elsif action='showcase.create'then
  perform boss_private.athlete_input(i,array['profile_id'],array['profile_id']);select *into p from public.athlete_profiles where id=boss_private.athlete_uuid(i,'profile_id')for share;
  if not boss_private.athlete_can_showcase(actor,p.id,'recruiting_showcases.manage')then raise exception'Access denied'using errcode='PT403';end if;
  insert into public.recruiting_showcases(profile_id,created_by_person_id)values(p.id,actor)on conflict(profile_id)do update set updated_at=public.recruiting_showcases.updated_at returning *into s;
  result:=jsonb_build_object('profile_id',p.id,'showcase_id',s.id,'version',s.version);perform boss_private.athlete_audit(actor,'recruiting_showcase.create','recruiting_showcase',s.id,p.person_id,request);

 elsif action='showcase.revise'then
  perform boss_private.athlete_input(i,array['showcase_id','expected_version','profile_revision_id','sport_keys','visible_categories','stat_metric_keys','presentation'],array['showcase_id','expected_version','profile_revision_id','sport_keys','visible_categories','stat_metric_keys','presentation']);
  select *into s from public.recruiting_showcases where id=boss_private.athlete_uuid(i,'showcase_id')for update;select *into p from public.athlete_profiles where id=s.profile_id for share;
  if not boss_private.athlete_can_showcase(actor,p.id,'recruiting_showcases.manage')then raise exception'Access denied'using errcode='PT403';end if;
  expected:=(i->>'expected_version')::bigint;if expected<>s.version then raise exception'Stale showcase version'using errcode='PT409';end if;
  if jsonb_typeof(i->'sport_keys')<>'array'or jsonb_array_length(i->'sport_keys')>8 or jsonb_typeof(i->'visible_categories')<>'array'or jsonb_array_length(i->'visible_categories')>9 or jsonb_typeof(i->'stat_metric_keys')<>'array'or jsonb_array_length(i->'stat_metric_keys')>32 or jsonb_typeof(i->'presentation')<>'object'or octet_length((i->'presentation')::text)>8192 then raise exception'Invalid showcase revision'using errcode='PT422';end if;
  select array_agg(x#>>'{}')into sports from jsonb_array_elements(i->'sport_keys')x;select array_agg(x#>>'{}')into categories from jsonb_array_elements(i->'visible_categories')x;select array_agg(x#>>'{}')into metrics from jsonb_array_elements(i->'stat_metric_keys')x;
  if exists(select 1 from unnest(coalesce(sports,'{}'))x where not exists(select 1 from public.game_sports where key=x and status='active'))or exists(select 1 from unnest(coalesce(metrics,'{}'))x where x!~'^[a-z][a-z0-9_]{0,63}$')then raise exception'Invalid showcase selector'using errcode='PT422';end if;
  if not exists(select 1 from public.athlete_profile_revisions pr where pr.id=boss_private.athlete_uuid(i,'profile_revision_id')and pr.profile_id=p.id)then raise exception'Invalid profile revision'using errcode='PT422';end if;
  select coalesce(max(revision),0)+1 into rev from public.recruiting_showcase_revisions where showcase_id=s.id;
  insert into public.recruiting_showcase_revisions(showcase_id,profile_revision_id,revision,sport_keys,visible_categories,stat_metric_keys,presentation,actor_person_id)values(s.id,boss_private.athlete_uuid(i,'profile_revision_id'),rev,coalesce(sports,'{}'),coalesce(categories,'{}'),coalesce(metrics,'{}'),i->'presentation',actor)returning *into sr;
  update public.recruiting_showcases set current_revision_id=sr.id,state=case when state='archived'then state else'draft'end,current_consent_id=null,version=version+1,updated_at=clock_timestamp()where id=s.id returning *into s;
  update public.recruiting_consents set status='revoked',revoked_at=clock_timestamp()where showcase_id=s.id and status='active';
  perform boss_private.athlete_audit(actor,'recruiting_showcase.revise','recruiting_showcase',s.id,p.person_id,request,jsonb_build_object('revision_id',sr.id,'version',s.version));result:=jsonb_build_object('profile_id',p.id,'showcase_id',s.id,'revision_id',sr.id,'version',s.version);

 elsif action='consent.grant'then
  perform boss_private.athlete_input(i,array['showcase_id','showcase_revision_id','approved_categories','expires_at'],array['showcase_id','showcase_revision_id','approved_categories']);
  select *into s from public.recruiting_showcases where id=boss_private.athlete_uuid(i,'showcase_id')for update;select *into p from public.athlete_profiles where id=s.profile_id for share;
  perform 1 from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=p.person_id order by id for share;
  if not boss_private.athlete_guardian(actor,p.person_id,true)then raise exception'Current guardian profile authority required'using errcode='PT403';end if;
  if s.current_revision_id is distinct from boss_private.athlete_uuid(i,'showcase_revision_id')then raise exception'Consent must match current revision'using errcode='PT409';end if;
  select array_agg(x#>>'{}')into categories from jsonb_array_elements(i->'approved_categories')x;select *into sr from public.recruiting_showcase_revisions where id=s.current_revision_id and showcase_id=s.id;
  if categories is null or not categories<@sr.visible_categories then raise exception'Consent exceeds revision fields'using errcode='PT422';end if;
  update public.recruiting_consents set status='revoked',revoked_at=clock_timestamp()where showcase_id=s.id and status='active';
  insert into public.recruiting_consents(showcase_id,showcase_revision_id,subject_person_id,actor_person_id,actor_kind,approved_categories,consent_version,expires_at)
  values(s.id,s.current_revision_id,p.person_id,actor,'guardian',categories,coalesce((select max(consent_version)+1 from public.recruiting_consents where showcase_id=s.id),1),(i->>'expires_at')::timestamptz)returning *into c;
  update public.recruiting_showcases set current_consent_id=c.id,version=version+1,updated_at=clock_timestamp()where id=s.id returning *into s;
  perform boss_private.athlete_audit(actor,'recruiting_showcase.consent_grant','recruiting_consent',c.id,p.person_id,request,jsonb_build_object('showcase_id',s.id,'revision_id',s.current_revision_id));result:=jsonb_build_object('profile_id',p.id,'showcase_id',s.id,'consent_id',c.id,'version',s.version);

 elsif action='showcase.publish'then
  perform boss_private.athlete_input(i,array['showcase_id','expected_version'],array['showcase_id','expected_version']);select *into s from public.recruiting_showcases where id=boss_private.athlete_uuid(i,'showcase_id')for update;select *into p from public.athlete_profiles where id=s.profile_id for share;
  perform 1 from public.guardian_relationships where dependent_person_id=p.person_id order by id for share;
  if not boss_private.athlete_can_showcase(actor,p.id,'recruiting_showcases.publish')then raise exception'Access denied'using errcode='PT403';end if;
  expected:=(i->>'expected_version')::bigint;if expected<>s.version then raise exception'Stale showcase version'using errcode='PT409';end if;
  select *into c from public.recruiting_consents where id=s.current_consent_id and showcase_id=s.id and showcase_revision_id=s.current_revision_id and status='active'and(expires_at is null or expires_at>clock_timestamp())for share;
  if c.id is null or not boss_private.athlete_guardian(c.actor_person_id,p.person_id,true)then raise exception'Current consent required'using errcode='PT403';end if;
  update public.recruiting_showcases set state='active',published_revision_id=current_revision_id,version=version+1,updated_at=clock_timestamp()where id=s.id returning *into s;
  perform boss_private.athlete_audit(actor,'recruiting_showcase.publish','recruiting_showcase',s.id,p.person_id,request,jsonb_build_object('revision_id',s.published_revision_id,'consent_id',s.current_consent_id));result:=jsonb_build_object('profile_id',p.id,'showcase_id',s.id,'version',s.version,'state',s.state);

 elsif action='share.create'then
  perform boss_private.athlete_input(i,array['showcase_id','token_digest','token_prefix','expires_at'],array['showcase_id','token_digest','token_prefix']);select *into s from public.recruiting_showcases where id=boss_private.athlete_uuid(i,'showcase_id')for update;select *into p from public.athlete_profiles where id=s.profile_id for share;
  if s.state<>'active'or not boss_private.athlete_can_showcase(actor,p.id,'recruiting_showcases.manage')then raise exception'Access denied'using errcode='PT403';end if;
  insert into public.recruiting_share_links(showcase_id,token_digest,token_prefix,expires_at,created_by_person_id)values(s.id,i->>'token_digest',i->>'token_prefix',(i->>'expires_at')::timestamptz,actor)returning id into resource;
  perform boss_private.athlete_audit(actor,'recruiting_showcase.share_create','recruiting_share_link',resource,p.person_id,request,jsonb_build_object('showcase_id',s.id,'expires_at',i->>'expires_at'));result:=jsonb_build_object('profile_id',p.id,'showcase_id',s.id,'share_link_id',resource);

 elsif action='share.revoke'then
  perform boss_private.athlete_input(i,array['share_link_id'],array['share_link_id']);select showcase.*into s from public.recruiting_showcases showcase join public.recruiting_share_links link on link.showcase_id=showcase.id where link.id=boss_private.athlete_uuid(i,'share_link_id')for update of showcase;select *into p from public.athlete_profiles where id=s.profile_id for share;
  if not boss_private.athlete_can_showcase(actor,p.id,'recruiting_showcases.manage')then raise exception'Access denied'using errcode='PT403';end if;
  update public.recruiting_share_links set status='revoked',revoked_at=clock_timestamp()where id=boss_private.athlete_uuid(i,'share_link_id')and status='active';
  perform boss_private.athlete_audit(actor,'recruiting_showcase.share_revoke','recruiting_share_link',boss_private.athlete_uuid(i,'share_link_id'),p.person_id,request,jsonb_build_object('showcase_id',s.id));result:=jsonb_build_object('profile_id',p.id,'showcase_id',s.id,'share_link_id',boss_private.athlete_uuid(i,'share_link_id'),'status','revoked');

 elsif action='showcase.disable'then
  perform boss_private.athlete_input(i,array['showcase_id'],array['showcase_id']);select *into s from public.recruiting_showcases where id=boss_private.athlete_uuid(i,'showcase_id')for update;select *into p from public.athlete_profiles where id=s.profile_id for share;
  if not boss_private.athlete_can_showcase(actor,p.id,'recruiting_showcases.manage')then raise exception'Access denied'using errcode='PT403';end if;
  update public.recruiting_showcases set state='disabled',version=version+1,updated_at=clock_timestamp()where id=s.id returning *into s;update public.recruiting_share_links set status='revoked',revoked_at=clock_timestamp()where showcase_id=s.id and status='active';update public.recruiting_consents set status='revoked',revoked_at=clock_timestamp()where showcase_id=s.id and status='active';
  perform boss_private.athlete_audit(actor,'recruiting_showcase.disable','recruiting_showcase',s.id,p.person_id,request);result:=jsonb_build_object('profile_id',p.id,'showcase_id',s.id,'version',s.version,'state',s.state);

 elsif action='profile.archive'then
  perform boss_private.athlete_input(i,array['profile_id'],array['profile_id']);select *into p from public.athlete_profiles where id=boss_private.athlete_uuid(i,'profile_id')for update;
  if not boss_private.athlete_can_manage(actor,p.id)then raise exception'Access denied'using errcode='PT403';end if;
  update public.athlete_profiles set status='archived',version=version+1,updated_at=clock_timestamp()where id=p.id;update public.recruiting_showcases set state='archived',version=version+1,updated_at=clock_timestamp()where profile_id=p.id;update public.recruiting_share_links set status='revoked',revoked_at=clock_timestamp()where showcase_id in(select id from public.recruiting_showcases where profile_id=p.id)and status='active';update public.recruiting_consents set status='revoked',revoked_at=clock_timestamp()where showcase_id in(select id from public.recruiting_showcases where profile_id=p.id)and status='active';
  perform boss_private.athlete_audit(actor,'athlete_profile.archive','athlete_profile',p.id,p.person_id,request);result:=jsonb_build_object('profile_id',p.id,'status','archived');
 else raise exception'Unsupported athlete-profile action'using errcode='PT422';end if;
 result:=result||jsonb_build_object('contract','athlete-profiles-v1','action',action);insert into boss_private.athlete_profile_operation_receipts(actor_person_id,request_id,input_hash,result)values(actor,request,input_hash,result);return result||jsonb_build_object('replayed',false);
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format then raise exception'Invalid athlete-profile value'using errcode='PT422';end$$;

revoke all on function boss_private.athlete_mutate(jsonb)from public,anon,authenticated,service_role;
create function public.boss_athlete_profile_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.athlete_mutate(command)$$;
revoke all on function public.boss_athlete_profile_mutate(jsonb)from public,anon,authenticated,service_role;
grant execute on function boss_private.athlete_mutate(jsonb),public.boss_athlete_profile_mutate(jsonb)to authenticated;
