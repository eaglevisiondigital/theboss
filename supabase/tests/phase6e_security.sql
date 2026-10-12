begin;
set local statement_timeout='8s';
\ir phase6e/fixture.sql
do $$declare t text;c text;f record;begin
 foreach t in array array['achievement_definitions','achievement_definition_revisions','entity_achievements','achievement_recognitions','achievement_history','achievement_display_choices','award_nominations','award_decisions','achievement_competition_closures','achievement_refresh_work']loop
  perform pg_temp.check(t||' RLS enabled','RLS',(select relrowsecurity from pg_class where oid=('public.'||t)::regclass));
  foreach c in array array['anon','authenticated','service_role']loop perform pg_temp.check(t||' raw closed to '||c,'ACL',not has_table_privilege(c,('public.'||t)::regclass,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));end loop;
 end loop;
 for f in select p.oid,p.oid::regprocedure sig,p.proconfig,p.proacl,p.proowner from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'achievement_%'loop
  perform pg_temp.check(f.sig||' fixed empty search path','SEARCH_PATH','search_path=""'=any(f.proconfig));
  perform pg_temp.check(f.sig||' PUBLIC execute closed','ACL',not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner)))a where a.grantee=0));
  perform pg_temp.check(f.sig||' anon helper closed','ACL',not has_function_privilege('anon',f.oid,'execute'));
 end loop;
end$$;
select pg_temp.check('three minimal permissions map only to approved administrators','PERMISSIONS',(select count(*)=6 and bool_and(r.key in('platform_administrator','organization_administrator'))from public.role_permissions rp join public.permissions p on p.id=rp.permission_id join public.roles r on r.id=rp.role_id where p.key in('achievement_definitions.manage','awards.issue','awards.approve')));
select pg_temp.check('anon has no private schema access','ACL',not has_schema_privilege('anon','boss_private','usage'));
select pg_temp.check('raw receipts closed','ACL',not has_table_privilege('authenticated','boss_private.achievement_operation_receipts','select'));
select pg_temp.check('anonymous achievement reads closed','ACL',not has_function_privilege('anon','public.boss_achievement_read(jsonb)','execute'));
select pg_temp.check('anonymous achievement mutations closed','ACL',not has_function_privilege('anon','public.boss_achievement_mutate(jsonb)','execute'));
select pg_temp.check('no automatic production definitions seeded','DEFINITIONS',(select count(*)=2 from public.achievement_definitions));
set local role authenticated;select pg_temp.actor('other-admin');
select pg_temp.denied('cross-tenant definition evaluation denied',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','definition.evaluate','request_id',gen_random_uuid(),'input',jsonb_build_object('definition_id',pg_temp.pe_id('career_one')))),'PT403');
select pg_temp.denied('cross-tenant recognition read denied',format('select public.boss_achievement_read(%L::jsonb)',jsonb_build_object('profile_id',pg_temp.pe_id('profile'))),'PT403');
select pg_temp.actor('household-only');
select pg_temp.denied('household alone grants no achievement access',format('select public.boss_achievement_read(%L::jsonb)',jsonb_build_object('profile_id',pg_temp.pe_id('profile'))),'PT403');
select pg_temp.denied('knowing recognition ID grants no history',format('select public.boss_achievement_read(%L::jsonb)',jsonb_build_object('recognition_id',(select id from pg_temp.phase6e_ids where label='profile'))),'PT403');
select pg_temp.actor('coach');
select pg_temp.denied('role capability cannot manage definitions',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','definition.rebuild','request_id',gen_random_uuid(),'input',jsonb_build_object('definition_id',pg_temp.pe_id('career_one')))),'PT403');
select pg_temp.actor('admin');
select pg_temp.check('unscoped recognition read cannot scan a global feed','BOUNDS',jsonb_array_length(public.boss_achievement_read('{}')->'recognitions')=0);
select pg_temp.denied('forged definition ID denied',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','definition.evaluate','request_id',gen_random_uuid(),'input',jsonb_build_object('definition_id',gen_random_uuid()))),'PT403');
select pg_temp.denied('forged profile cannot be awarded',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','award.nominate','request_id',gen_random_uuid(),'input',jsonb_build_object('definition_id',pg_temp.pe_id('manual_mvp'),'organization_id',pg_temp.f('org'),'team_id',pg_temp.f('wildcats'),'profile_id',gen_random_uuid(),'achieved_at',clock_timestamp(),'note','Invalid'))),'PT422');
select pg_temp.denied('legacy ad hoc honor cannot bypass approval',format('select public.boss_athlete_profile_mutate(%L::jsonb)',jsonb_build_object('action','achievement.add','request_id',gen_random_uuid(),'input',jsonb_build_object('profile_id',pg_temp.pe_id('profile'),'title','Bypass','achievement_type','team_award','visibility','showcase'))),'PT422');
select pg_temp.denied('arbitrary SQL rule not permitted',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','definition.create','request_id',gen_random_uuid(),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'owner_kind','organization','definition_key','sql_injection','revision',pg_temp.pe_rule('Invalid',jsonb_build_object('sql','select true'))))),'PT422');
select pg_temp.denied('unknown denominator cannot become milestone',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','definition.create','request_id',gen_random_uuid(),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'owner_kind','organization','definition_key','invalid_rate','revision',pg_temp.pe_rule('Invalid rate','{"metric_key":"avg"}')))),'PT422');
select pg_temp.denied('uploaded SVG is not badge authority',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','definition.create','request_id',gen_random_uuid(),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'owner_kind','organization','definition_key','invalid_svg','revision',pg_temp.pe_rule('Invalid badge','{"badge_icon":"<svg onload=evil>"}')))),'PT422');
reset role;
-- Current Wildcats relationship never gives access to private Falcons origins.
update public.team_memberships set status='inactive',ends_at=clock_timestamp()where participant_id=pg_temp.f('participant-child1')and team_id=pg_temp.f('falcons');
insert into public.team_memberships(id,organization_id,team_id,person_id,participant_id,membership_type,status,starts_at)values(pg_temp.f('phase6e-child-transfer'),pg_temp.f('org'),pg_temp.f('wildcats'),pg_temp.f('child1'),pg_temp.f('participant-child1'),'athlete','active',clock_timestamp());
insert into public.team_memberships(id,organization_id,team_id,person_id,membership_type,status,starts_at)values(pg_temp.f('phase6e-coach-transfer'),pg_temp.f('org'),pg_temp.f('wildcats'),pg_temp.f('coach'),'staff','active',clock_timestamp());
insert into public.role_assignments(person_id,role_id,organization_id,scope_type,scope_id,status,starts_at)select person_id,role_id,organization_id,scope_type,pg_temp.f('wildcats'),'active',clock_timestamp()from public.role_assignments where person_id=pg_temp.f('coach')and scope_type='team'and status='active';
update public.role_assignments set status='inactive',ends_at=clock_timestamp()where person_id=pg_temp.f('coach')and scope_type='team'and scope_id=pg_temp.f('falcons');
set local role authenticated;select pg_temp.actor('coach');
select pg_temp.check('new team sees no private prior honors','TRANSFER',jsonb_array_length(public.boss_achievement_read(jsonb_build_object('profile_id',pg_temp.pe_id('profile')))->'recognitions')=0);
select pg_temp.actor('parent');
select pg_temp.check('guardian retains prior verified milestone','TRANSFER',jsonb_array_length(public.boss_achievement_read(jsonb_build_object('profile_id',pg_temp.pe_id('profile')))->'recognitions')=1);
reset role;
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
