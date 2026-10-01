-- Independent permission catalogs and immutable/sensitive ACL boundaries.
BEGIN;
CREATE TEMP TABLE phase3b_security_assertions(label text PRIMARY KEY) ON COMMIT DROP;
CREATE FUNCTION pg_temp.check(label text,ok boolean) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL security %',label;END IF;INSERT INTO pg_temp.phase3b_security_assertions VALUES(label);END $$;
DO $$DECLARE role_key text;expected text[];actual text[];permission_keys text[]:=ARRAY['documents.emergency_view','documents.review','documents.view','fees.manage','fees.view','forms.manage','payments.record_offline','registration.create','registration.manage','registration.review','registration.view','waivers.manage'];fn text;tab text;BEGIN
 PERFORM pg_temp.check('exact finite Phase3B permissions',(SELECT array_agg(key ORDER BY key)=permission_keys FROM public.permissions WHERE key=ANY(permission_keys)));
 FOR role_key IN SELECT key FROM public.roles ORDER BY key LOOP
  expected:=CASE WHEN role_key IN('super_administrator','platform_administrator','organization_owner','organization_administrator') THEN permission_keys
   WHEN role_key IN('registrar','program_administrator','sport_administrator','athletic_director') THEN ARRAY['documents.review','documents.view','forms.manage','registration.create','registration.manage','registration.review','registration.view','waivers.manage']
   WHEN role_key IN('finance','organization_finance') THEN ARRAY['fees.manage','fees.view','payments.record_offline']
   WHEN role_key IN('head_coach','assistant_coach','team_staff') THEN ARRAY['documents.emergency_view','registration.view'] ELSE ARRAY[]::text[] END;
  SELECT coalesce(array_agg(p.key ORDER BY p.key),ARRAY[]::text[]) INTO actual FROM public.roles r JOIN public.role_permissions rp ON rp.role_id=r.id JOIN public.permissions p ON p.id=rp.permission_id WHERE r.key=role_key AND p.key=ANY(permission_keys);
  PERFORM pg_temp.check('approved new potential capability only '||role_key,actual=expected);
 END LOOP;
 PERFORM pg_temp.check('new registrar exact allowed scopes',(SELECT allowed_scope_types=ARRAY['organization','organization_unit','team'] FROM public.roles WHERE key='registrar'));
 PERFORM pg_temp.check('new organization finance exact allowed scopes',(SELECT allowed_scope_types=ARRAY['organization','organization_unit','team'] FROM public.roles WHERE key='organization_finance'));
 FOREACH fn IN ARRAY ARRAY['public.boss_registration_mutate(uuid,jsonb)','public.boss_registration_read(jsonb)'] LOOP
  PERFORM pg_temp.check(fn||' caller-only RPC',has_function_privilege('authenticated',fn,'EXECUTE') AND NOT has_function_privilege('anon',fn,'EXECUTE') AND NOT has_function_privilege('service_role',fn,'EXECUTE'));
  PERFORM pg_temp.check(fn||' public invoker',(SELECT NOT prosecdef FROM pg_catalog.pg_proc WHERE oid=fn::regprocedure));
 END LOOP;
 FOREACH tab IN ARRAY ARRAY['registration_operation_receipts','document_access_leases','registration_document_history'] LOOP
  PERFORM pg_temp.check(tab||' private RLS',(SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid=('boss_private.'||tab)::regclass));
  PERFORM pg_temp.check(tab||' no raw client receipt/lease grants',NOT has_table_privilege('authenticated','boss_private.'||tab,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE') AND NOT has_table_privilege('anon','boss_private.'||tab,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
 END LOOP;
 PERFORM pg_temp.check('no public definer endpoint',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef));
 PERFORM pg_temp.check('storage actual RLS remains enabled',(SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid='storage.objects'::regclass));
 PERFORM pg_temp.check('storage policies only immutable upload/read',(SELECT count(*)=2 AND bool_and(cmd IN('INSERT','SELECT')) AND bool_and(roles=ARRAY['authenticated']::name[]) FROM pg_catalog.pg_policies WHERE schemaname='storage' AND policyname IN('boss_registration_document_upload','boss_registration_document_download')));
 PERFORM pg_temp.check('private helper/trigger search paths empty',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='boss_private' AND NOT coalesce('search_path=""'=ANY(p.proconfig),false)));
 PERFORM pg_temp.check('no PUBLIC private helper execution',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='boss_private' AND EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE')));
 PERFORM pg_temp.check('all registration FKs have covering indexes',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_namespace n ON n.oid=c.connamespace WHERE c.contype='f' AND n.nspname IN('public','boss_private') AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_index i WHERE i.indrelid=c.conrelid AND i.indisvalid AND i.indpred IS NULL AND i.indexprs IS NULL AND i.indnkeyatts>=cardinality(c.conkey) AND (i.indkey::smallint[])[0:cardinality(c.conkey)-1] @> c.conkey)));
END $$;
SELECT count(*) AS passed_assertions FROM pg_temp.phase3b_security_assertions;
ROLLBACK;
