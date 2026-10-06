-- Disposable synthetic Phase 6C fixture.
\ir ../phase6b/fixture.sql
update public.guardian_relationships set can_manage_profile=true where id=pg_temp.f('guardian-child1');
create temp table phase6c_ids(label text primary key,id uuid not null)on commit drop;
grant select,insert,update on phase6c_ids to authenticated;
create function pg_temp.pc_id(k text)returns uuid language sql stable as $$select id from pg_temp.phase6c_ids where label=k$$;
create function pg_temp.pc(action text,input jsonb,p_label text default null,request uuid default null)returns jsonb language plpgsql as $$declare result jsonb;resource uuid;begin
 result:=public.boss_athlete_profile_mutate(jsonb_build_object('action',action,'request_id',coalesce(request,gen_random_uuid()),'input',input));
 if p_label is not null then resource:=case when action='showcase.create'then(result->>'showcase_id')::uuid when action='showcase.revise'then(result->>'revision_id')::uuid when action='consent.grant'then(result->>'consent_id')::uuid when action like'share.%'then(result->>'share_link_id')::uuid when action='measurable.add'then(result->>'measurable_id')::uuid when action='achievement.add'then(result->>'achievement_id')::uuid when action='media.add'then(result->>'media_id')::uuid else(result->>'profile_id')::uuid end;insert into pg_temp.phase6c_ids values(p_label,resource)on conflict(label)do update set id=excluded.id;end if;return result;end$$;
revoke all on function pg_temp.pc_id(text),pg_temp.pc(text,jsonb,text,uuid)from public;grant execute on function pg_temp.pc_id(text),pg_temp.pc(text,jsonb,text,uuid)to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.pc('profile.create',jsonb_build_object('participant_id',pg_temp.f('participant-child1'),'visibility','athlete_guardian','safe_fields',jsonb_build_object('display_name','Synthetic Child One','positions',jsonb_build_array('Forward'),'class_year',2032,'bio','Synthetic multi-sport athlete.')),'profile');
select pg_temp.pc('showcase.create',jsonb_build_object('profile_id',pg_temp.pc_id('profile')),'showcase');
select pg_temp.pc('showcase.revise',jsonb_build_object('showcase_id',pg_temp.pc_id('showcase'),'expected_version',1,'profile_revision_id',public.boss_athlete_profile_read(pg_temp.pc_id('profile'),null)->'profile'->'profile'->>'current_revision_id','sport_keys',jsonb_build_array('baseball'),'visible_categories',jsonb_build_array('overview','sports','statistics','measurables','achievements','history','media'),'stat_metric_keys',jsonb_build_array('home_runs','hits'),'presentation',jsonb_build_object('headline','Synthetic athlete showcase')),'showcase-revision');
select pg_temp.pc('measurable.add',jsonb_build_object('profile_id',pg_temp.pc_id('profile'),'sport_key','baseball','metric_key','sprint_seconds','value',5.10,'unit','s','measured_on',current_date,'provenance','organization_verified','visibility','showcase','organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'),'source_label','Synthetic combine'),'measurable');
select pg_temp.pc('achievement.add',jsonb_build_object('profile_id',pg_temp.pc_id('profile'),'sport_key','baseball','achievement_type','team_award','title','Synthetic team award','achieved_on',current_date,'organization_id',pg_temp.f('org'),'visibility','showcase'),'achievement');
reset role;
