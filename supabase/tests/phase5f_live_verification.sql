-- Read-only structural checks usable both locally and after canonical application.
begin;
do $$declare t text;f record;passed int:=0;flags jsonb;begin
 foreach t in array array['game_diamond_states','game_diamond_events','game_diamond_plate_appearances','game_diamond_finalizations','game_diamond_final_stats']loop
 if not exists(select 1 from pg_class where oid=('public.'||t)::regclass and relrowsecurity)or exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass)then raise exception 'Phase5F closed RLS differs: %',t;end if;passed:=passed+1;
 if has_table_privilege('authenticated','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')or has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')or has_table_privilege('service_role','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')then raise exception 'Phase5F raw privilege differs: %',t;end if;passed:=passed+1;
 if t not in('game_diamond_states')and not exists(select 1 from pg_trigger where tgrelid=('public.'||t)::regclass and tgfoid='boss_private.reject_audit_rewrite()'::regprocedure and not tgisinternal and tgenabled='O')then raise exception 'Phase5F immutable protection differs: %',t;end if;passed:=passed+1;
 end loop;
 for f in select p.*from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and(p.proname like'diamond_%'or p.proname='tracking_at')loop
 if not coalesce('search_path=""'=any(f.proconfig),false)or has_function_privilege('authenticated',f.oid,'EXECUTE')or has_function_privilege('anon',f.oid,'EXECUTE')or has_function_privilege('service_role',f.oid,'EXECUTE')or exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE')then raise exception 'Phase5F private helper differs';end if;passed:=passed+1;
 end loop;
 flags:=boss_private.games_configuration(null);
 foreach t in array array['baseball_live_scoring','baseball_stats','baseball_play_by_play','baseball_lineups','softball_live_scoring','softball_stats','softball_play_by_play','softball_lineups']loop
 if flags->>t is distinct from'false'or boss_private.games_feature(null,t,jsonb_build_object('game_center',true,t,true))then raise exception 'Phase5F feature without module/default differs';end if;passed:=passed+1;end loop;
 if exists(select 1 from public.game_diamond_states s join public.games g on g.id=s.game_id where g.sport_key is distinct from s.sport_key or s.organization_id<>g.organization_id or s.roster_revision<>g.roster_revision)then raise exception 'Phase5F canonical sport identity differs';end if;passed:=passed+1;
 if exists(select 1 from public.game_diamond_states v where exists(select 1 from public.game_basketball_states b where b.game_id=v.game_id)or exists(select 1 from public.game_soccer_states s where s.game_id=v.game_id)or exists(select 1 from public.game_football_states ff where ff.game_id=v.game_id)or exists(select 1 from public.game_volleyball_states vv where vv.game_id=v.game_id))then raise exception 'Phase5F multiple engines in one game';end if;passed:=passed+1;
 if exists(select 1 from public.game_stat_catalog_items c where c.definition->>'key'<>c.key or jsonb_array_length(c.definition->'scopes')<1)then raise exception 'Phase5F finite catalog metadata differs';end if;passed:=passed+1;
 perform set_config('boss.phase5f_live_assertions',passed::text,true);
end$$;
select current_setting('boss.phase5f_live_assertions')::int passed_assertions;
rollback;
