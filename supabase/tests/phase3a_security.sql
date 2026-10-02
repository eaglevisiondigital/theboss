-- Independently verify exact new capability mappings and default-deny surfaces.
BEGIN;
DO $security$
DECLARE v_role text;v_expected text[];v_actual text[];v_passed integer:=0;v_fn text;v_schema text;
BEGIN
 FOR v_role IN SELECT key FROM public.roles ORDER BY key LOOP
  v_expected:=CASE WHEN v_role IN ('super_administrator','platform_administrator','organization_owner','organization_administrator') THEN ARRAY['events.create','events.manage','events.override_conflict','events.publish','events.view']
   WHEN v_role IN ('athletic_director','program_administrator','sport_administrator','head_coach') THEN ARRAY['events.create','events.manage','events.view']
   WHEN v_role IN ('assistant_coach','team_administrator','team_staff') THEN ARRAY['events.view'] ELSE ARRAY[]::text[] END;
  SELECT coalesce(array_agg(p.key ORDER BY p.key),ARRAY[]::text[]) INTO v_actual FROM public.roles r JOIN public.role_permissions rp ON rp.role_id=r.id JOIN public.permissions p ON p.id=rp.permission_id WHERE r.key=v_role AND p.key LIKE 'events.%';
  IF v_actual IS DISTINCT FROM v_expected THEN RAISE EXCEPTION 'FAIL calendar mapping %',v_role;END IF;v_passed:=v_passed+1;
 END LOOP;
 IF (SELECT count(*) FROM public.roles WHERE key NOT IN ('registrar','organization_finance'))<>19 OR (SELECT count(*) FROM public.permissions WHERE key NOT IN ('registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view'))<>22 OR (SELECT count(*) FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view'))<>147 OR (SELECT count(*) FROM public.modules)<>14 THEN RAISE EXCEPTION 'FAIL approved catalog totals';END IF;v_passed:=v_passed+1;
 IF has_schema_privilege('anon','boss_private','USAGE') THEN RAISE EXCEPTION 'FAIL anonymous private schema opened';END IF;v_passed:=v_passed+1;
 FOREACH v_fn IN ARRAY ARRAY['public.boss_calendar_read(jsonb)','public.boss_calendar_mutate(jsonb,uuid)','public.boss_calendar_preview(jsonb)'] LOOP
  IF NOT has_function_privilege('authenticated',v_fn,'EXECUTE') OR has_function_privilege('anon',v_fn,'EXECUTE') THEN RAISE EXCEPTION 'FAIL authenticated RPC ACL %',v_fn;END IF;v_passed:=v_passed+1;
  IF (SELECT prosecdef FROM pg_catalog.pg_proc WHERE oid=v_fn::regprocedure) THEN RAISE EXCEPTION 'FAIL public RPC definer %',v_fn;END IF;v_passed:=v_passed+1;
 END LOOP;
 IF NOT has_function_privilege('anon','public.boss_calendar_public_read(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'FAIL published RPC ACL';END IF;v_passed:=v_passed+1;
 IF has_table_privilege('authenticated','boss_private.calendar_operation_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE') OR has_table_privilege('anon','boss_private.calendar_operation_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE') THEN RAISE EXCEPTION 'FAIL receipt ACL';END IF;v_passed:=v_passed+1;
 IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid='boss_private.calendar_operation_receipts'::regclass) THEN RAISE EXCEPTION 'FAIL receipt RLS';END IF;v_passed:=v_passed+1;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('boss_private','boss_calendar_public') AND NOT coalesce('search_path=""'=ANY(p.proconfig),false)) THEN RAISE EXCEPTION 'FAIL private search path';END IF;v_passed:=v_passed+1;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='boss_calendar_public' AND p.proname<>'read_schedule') THEN RAISE EXCEPTION 'FAIL unexpected public projector';END IF;v_passed:=v_passed+1;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('boss_private','boss_calendar_public') AND EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl WHERE grantee=0 AND privilege_type='EXECUTE')) THEN RAISE EXCEPTION 'FAIL PUBLIC private execute';END IF;v_passed:=v_passed+1;
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_namespace n ON n.oid=c.connamespace WHERE c.contype='f' AND n.nspname IN ('public','boss_private') AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_index i WHERE i.indrelid=c.conrelid AND i.indisvalid AND i.indpred IS NULL AND i.indexprs IS NULL AND i.indnkeyatts>=cardinality(c.conkey) AND (i.indkey::smallint[])[0:cardinality(c.conkey)-1] @> c.conkey)) THEN RAISE EXCEPTION 'FAIL missing foreign key index';END IF;v_passed:=v_passed+1;
 PERFORM set_config('boss.phase3a_security_assertions',v_passed::text,true);
END;
$security$;
SELECT current_setting('boss.phase3a_security_assertions')::integer AS passed_assertions;
ROLLBACK;
