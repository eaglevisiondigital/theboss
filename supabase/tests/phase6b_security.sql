begin;
set local statement_timeout='8s';
create temp table rb_assertions(label text primary key);
create function pg_temp.ok(label text,condition boolean)returns void language plpgsql as $$begin if condition is distinct from true then raise exception 'FAIL Phase6B %',label;end if;insert into rb_assertions values(label);end$$;
do $$declare tab record;f record;role_key text;permission text;expected boolean;actual boolean;client text;
 keys text[]:=array['competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild'];begin
 perform pg_temp.ok('exact twelve permission extension',(select count(*)=12 from public.permissions where key=any(keys)));
 perform pg_temp.ok('exact competition-manager scope types',(select allowed_scope_types=array['competition','competition_edition']::text[]from public.roles where key='competition_manager'));
 for role_key in select key from public.roles order by key loop
 foreach permission in array keys loop
 expected:=role_key in('platform_administrator','organization_administrator','competition_manager')or(role_key in('athletic_director','program_administrator','sport_administrator')and permission not in('competition.manage','competition.policy_manage'))or(role_key in('head_coach','team_administrator')and permission in('competition.view','standings.view','leaderboard.view','records.view'));
 select exists(select 1 from public.roles r join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id where r.key=role_key and p.key=permission)into actual;
 perform pg_temp.ok('finite capability:'||role_key||':'||permission,actual=expected);
 end loop;end loop;
 for tab in select c.oid,n.nspname,c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r'and((n.nspname='public'and c.relname=any(array['competitions','competition_editions','competition_groups','competition_entries','competition_entry_groups','competition_access_assignments','standings_policy_revisions','competition_game_assignments','competition_game_assignment_groups','competition_rulings','ranking_definitions','ranking_scopes','standings_rows','ranking_candidates','record_events','record_current_holders','ranking_refresh_work']))or(n.nspname='boss_private'and c.relname='ranking_operation_receipts'))loop
 perform pg_temp.ok(tab.relname||' RLS enabled',tab.relrowsecurity);
 foreach client in array array['anon','authenticated','service_role']loop perform pg_temp.ok(tab.relname||' raw closed:'||client,not has_table_privilege(client,tab.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));end loop;
 end loop;
 for f in select p.oid,p.oid::regprocedure signature,p.proname,n.nspname,p.prosecdef,p.proconfig,p.proacl,p.proowner from pg_proc p join pg_namespace n on n.oid=p.pronamespace where(n.nspname='boss_private'and p.proname like'ranking_%')or(n.nspname='public'and p.proname in('boss_ranking_read','boss_ranking_mutate'))loop
 perform pg_temp.ok(f.signature||' empty search path',coalesce('search_path=""'=any(f.proconfig),false));
 perform pg_temp.ok(f.signature||' PUBLIC execute closed',not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE'));
 perform pg_temp.ok(f.signature||' anonymous/service execute closed',not has_function_privilege('anon',f.oid,'EXECUTE')and not has_function_privilege('service_role',f.oid,'EXECUTE'));
 if f.nspname='public'then perform pg_temp.ok(f.signature||' authenticated invoker entry',not f.prosecdef and has_function_privilege('authenticated',f.oid,'EXECUTE'));
 elsif f.proname not in('ranking_read','ranking_mutate')then perform pg_temp.ok(f.signature||' private helper closed',not has_function_privilege('authenticated',f.oid,'EXECUTE'));end if;
 end loop;
 perform pg_temp.ok('no anonymous athlete publication policy',not exists(select 1 from pg_policies where tablename=any(array['ranking_candidates','record_events','record_current_holders'])and('anon'=any(roles)or'public'=any(roles))));
end$$;
select count(*)passed_assertions from rb_assertions;
rollback;
