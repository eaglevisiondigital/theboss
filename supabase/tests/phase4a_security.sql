-- Independent Phase 4A capability matrix and API privilege boundary.
BEGIN;
CREATE TEMP TABLE phase4a_security_assertions(label text PRIMARY KEY) ON COMMIT DROP;
CREATE FUNCTION pg_temp.check(label text,ok boolean) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL Phase4A security %',label;END IF;
 INSERT INTO pg_temp.phase4a_security_assertions VALUES(label);
END $$;
DO $$
DECLARE role_key text;expected text[];actual text[];tab record;fn record;client_role text;
 keys text[]:=ARRAY['announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view'];
BEGIN
 PERFORM pg_temp.check('exact evolved catalogs',
  (SELECT count(*)=21 FROM public.roles) AND (SELECT count(*)=44 FROM public.permissions WHERE key NOT IN ('attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign') AND key NOT LIKE 'games.%')
  AND (SELECT count(*)=306 FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign') AND p.key NOT LIKE 'games.%')
  AND (SELECT count(*)=63 FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename NOT IN ('event_attendance_settings','attendance_responses','attendance_response_history','attendance_checkins','attendance_checkin_history','attendance_requests','volunteer_role_definitions','volunteer_shifts','volunteer_assignments','volunteer_assignment_history') AND tablename NOT IN ('game_sports','games','game_roster_snapshots','game_operator_assignments','game_operations','game_finalizations') AND tablename NOT IN ('game_basketball_states','game_basketball_events','game_basketball_lineups','game_basketball_lineup_history','game_basketball_finalizations','game_basketball_final_stats') AND tablename NOT IN ('game_soccer_states','game_soccer_events','game_soccer_lineups','game_soccer_finalizations','game_soccer_final_stats')));
 PERFORM pg_temp.check('exact finite Phase4A permission catalog',(SELECT array_agg(key ORDER BY key)=keys FROM public.permissions WHERE key=ANY(keys)));
 FOR role_key IN SELECT key FROM public.roles ORDER BY key LOOP
  expected:=CASE
   WHEN role_key IN('super_administrator','platform_administrator','organization_owner','organization_administrator') THEN keys
   WHEN role_key='athletic_director' THEN ARRAY['announcements.send','communications.view']
   WHEN role_key IN('program_administrator','sport_administrator') THEN ARRAY['announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','team_chat.send','team_chat.view']
   WHEN role_key='head_coach' THEN ARRAY['announcements.send','communications.manage','communications.view','team_chat.send','team_chat.view']
   WHEN role_key IN('assistant_coach','team_staff') THEN ARRAY['communications.view','team_chat.send','team_chat.view']
   ELSE ARRAY[]::text[] END;
  SELECT coalesce(array_agg(p.key ORDER BY p.key),ARRAY[]::text[]) INTO actual
   FROM public.roles r JOIN public.role_permissions rp ON rp.role_id=r.id JOIN public.permissions p ON p.id=rp.permission_id
   WHERE r.key=role_key AND p.key=ANY(keys);
  PERFORM pg_temp.check('least privilege potential capability '||role_key,actual=expected);
 END LOOP;
 FOR tab IN SELECT n.nspname schema_name,c.relname name,c.oid,c.relrowsecurity
  FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE c.relkind='r' AND n.nspname IN('public','boss_private')
   AND (c.relname LIKE 'communication_%' OR c.relname LIKE 'notification_%' OR c.relname='notifications') LOOP
  PERFORM pg_temp.check(tab.schema_name||'.'||tab.name||' RLS enabled',tab.relrowsecurity);
  FOREACH client_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
   PERFORM pg_temp.check(tab.schema_name||'.'||tab.name||' closed to '||client_role,
    NOT has_table_privilege(client_role,tab.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));
  END LOOP;
 END LOOP;
 FOR fn IN SELECT p.oid,p.oid::regprocedure signature,p.prosecdef,p.proconfig,p.proacl,p.proowner,n.nspname schema_name,p.proname
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  WHERE (n.nspname='public' AND p.proname IN('boss_communications_read','boss_communications_mutate','boss_notifications_read','boss_notifications_mutate'))
   OR (n.nspname='boss_private' AND (p.proname LIKE 'comm_%' OR p.proname LIKE 'notification_%' OR p.proname IN('notifications_read','notifications_mutate'))) LOOP
  PERFORM pg_temp.check(fn.signature||' empty search_path',coalesce('search_path=""'=ANY(fn.proconfig),false));
  PERFORM pg_temp.check(fn.signature||' no PUBLIC execution',NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(fn.proacl,acldefault('f',fn.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE'));
  PERFORM pg_temp.check(fn.signature||' no anon/service execution',NOT has_function_privilege('anon',fn.oid,'EXECUTE') AND NOT has_function_privilege('service_role',fn.oid,'EXECUTE'));
  IF fn.schema_name='public' THEN
   PERFORM pg_temp.check(fn.signature||' public invoker only',NOT fn.prosecdef);
   PERFORM pg_temp.check(fn.signature||' authenticated entry',has_function_privilege('authenticated',fn.oid,'EXECUTE'));
  ELSIF fn.proname NOT IN('comm_read','comm_mutate','comm_storage_insert','comm_storage_select','notifications_read','notifications_mutate') THEN
   PERFORM pg_temp.check(fn.signature||' helper inaccessible to authenticated',NOT has_function_privilege('authenticated',fn.oid,'EXECUTE'));
  END IF;
 END LOOP;
 PERFORM pg_temp.check('new guardian capabilities default false and required',(SELECT count(*)=2 AND bool_and(a.attnotnull) AND bool_and(pg_get_expr(d.adbin,d.adrelid)='false') FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid='public.guardian_relationships'::regclass AND a.attname IN('can_receive_communications','can_send_communications')));
END $$;
SELECT count(*) AS passed_assertions FROM pg_temp.phase4a_security_assertions;
ROLLBACK;
