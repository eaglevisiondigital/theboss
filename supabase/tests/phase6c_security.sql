begin;
create temp table pc_assertions(label text primary key);
create function pg_temp.pc_ok(label text,condition boolean)returns void language plpgsql as $$begin if condition is distinct from true then raise exception'FAIL Phase6C %',label;end if;insert into pc_assertions values(label);end$$;
do $$declare tab record;client text;permission text;role_key text;actual boolean;expected boolean;f record;keys text[]:=array['athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish'];begin
 perform pg_temp.pc_ok('exact six permission extension',(select count(*)=6 from public.permissions where key=any(keys)));
 for role_key in select key from public.roles order by key loop foreach permission in array keys loop
  expected:=role_key in('platform_administrator','organization_administrator')or(role_key in('athletic_director','program_administrator','sport_administrator')and permission in('athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view'))or(role_key in('head_coach','team_administrator')and permission in('athlete_profiles.view','athlete_profiles.verify','recruiting_showcases.view'));
  select exists(select 1 from public.roles r join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id where r.key=role_key and p.key=permission)into actual;perform pg_temp.pc_ok('finite capability:'||role_key||':'||permission,actual=expected);
 end loop;end loop;
 for tab in select c.oid,c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r'and((n.nspname='public'and c.relname=any(array['athlete_profiles','athlete_profile_revisions','athlete_measurables','athlete_achievements','athlete_profile_verifications','athlete_media_links','recruiting_showcases','recruiting_showcase_revisions','recruiting_consents','recruiting_share_links']))or(n.nspname='boss_private'and c.relname='athlete_profile_operation_receipts'))loop
  perform pg_temp.pc_ok(tab.relname||' RLS enabled',tab.relrowsecurity);foreach client in array array['anon','authenticated','service_role']loop perform pg_temp.pc_ok(tab.relname||' raw closed:'||client,not has_table_privilege(client,tab.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));end loop;
 end loop;
 for f in select p.oid,p.oid::regprocedure signature,p.proname,n.nspname,p.proconfig,p.proacl,p.proowner from pg_proc p join pg_namespace n on n.oid=p.pronamespace where(n.nspname='boss_private'and p.proname like'athlete_%')or(n.nspname='public'and p.proname like'boss_athlete_%')or(n.nspname='public'and p.proname='boss_recruiting_showcase_read')loop
  perform pg_temp.pc_ok(f.signature||' empty search path',coalesce('search_path=""'=any(f.proconfig),false));perform pg_temp.pc_ok(f.signature||' PUBLIC execute closed',not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE'));
  if f.proname<>'boss_recruiting_showcase_read'then perform pg_temp.pc_ok(f.signature||' anonymous closed',not has_function_privilege('anon',f.oid,'EXECUTE'));end if;
 end loop;
 perform pg_temp.pc_ok('no public athlete listing function',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname like'%athlete%search%'));
 perform pg_temp.pc_ok('no anonymous raw profile policy',not exists(select 1 from pg_policies where tablename like'athlete_%'and('anon'=any(roles)or'public'=any(roles))));
end$$;
select count(*)passed_assertions from pc_assertions;
rollback;
