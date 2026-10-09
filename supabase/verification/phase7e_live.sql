-- Read-only canonical verifier; no fixture, mutation, Auth identifiers or secrets.
begin read only;
do $verify$
declare relation record;fn record;role text;missing text;n integer:=0;
begin
 if(select count(*)from pg_class c join pg_namespace ns on ns.oid=c.relnamespace where ns.nspname='public'and c.relkind='r'and c.relname like'discount\_%'escape'\')<>20 then raise exception'Expected 20 Phase 7E public relations';end if;
 for relation in select c.*,ns.nspname from pg_class c join pg_namespace ns on ns.oid=c.relnamespace where ns.nspname in('public','boss_private')and c.relkind='r'and c.relname like'discount\_%'escape'\'loop
 if not relation.relrowsecurity then raise exception'Raw relation RLS missing';end if;
 if exists(select 1 from pg_policy where polrelid=relation.oid)then raise exception'Raw relation policy opened';end if;
 if exists(select 1 from aclexplode(coalesce(relation.relacl,acldefault('r',relation.relowner)))a where a.grantee=0)then raise exception'Raw PUBLIC ACL opened';end if;
 foreach role in array array['anon','authenticated','service_role','boss_payment_worker']loop
 if has_table_privilege(role,relation.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')then raise exception'Raw client ACL opened';end if;end loop;
 if exists(select 1 from pg_constraint where conrelid=relation.oid and not convalidated)or exists(select 1 from pg_index where indrelid=relation.oid and(not indisvalid or not indisready))then raise exception'Unvalidated schema object';end if;n:=n+1;
 end loop;
 for fn in select p.*,ns.nspname from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where(ns.nspname='boss_private'and p.proname like'discount\_%'escape'\')or ns.nspname='boss_discounts_public'or(ns.nspname='public'and p.proname like'boss_discounts_%')loop
 if not coalesce('search_path=""'=any(fn.proconfig),false)then raise exception'Helper search path differs';end if;
 if exists(select 1 from aclexplode(coalesce(fn.proacl,acldefault('f',fn.proowner)))a where a.grantee=0 and privilege_type='EXECUTE')then raise exception'PUBLIC helper execution opened';end if;
 if has_function_privilege('service_role',fn.oid,'EXECUTE')or has_function_privilege('boss_payment_worker',fn.oid,'EXECUTE')then raise exception'Unintended helper execution';end if;
 if fn.nspname='boss_private'and fn.proname not in('discount_read','discount_mutate')and(has_function_privilege('anon',fn.oid,'EXECUTE')or has_function_privilege('authenticated',fn.oid,'EXECUTE'))then raise exception'Private helper client execution';end if;n:=n+1;
 end loop;
 select string_agg(c.conname,',')into missing from pg_constraint c join pg_class r on r.oid=c.conrelid join pg_namespace ns on ns.oid=r.relnamespace
 where c.contype='f'and ns.nspname in('public','boss_private')and r.relname like'discount\_%'escape'\'and not exists(select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and i.indpred is null and i.indexprs is null and i.indnkeyatts>=cardinality(c.conkey)and(i.indkey::smallint[])[0:cardinality(c.conkey)-1]@>c.conkey);
 if missing is not null then raise exception'Unindexed Phase 7E FK';end if;
 if(select count(*)from public.permissions where key in('boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage'))<>5 then raise exception'Finite membership permissions differ';end if;
 if not has_function_privilege('authenticated','public.boss_discounts_read(jsonb)','EXECUTE')or has_function_privilege('anon','public.boss_discounts_read(jsonb)','EXECUTE')then raise exception'Signed projection ACL differs';end if;
 if not has_function_privilege('anon','public.boss_discounts_catalog(uuid,text)','EXECUTE')or not has_function_privilege('anon','public.boss_discounts_support(jsonb)','EXECUTE')then raise exception'Public catalog/claim ACL differs';end if;
 perform set_config('boss.phase7e_schema_checks',n::text,true);
end $verify$;
select 'PASS' status,current_setting('boss.phase7e_schema_checks')::integer checked_relations_functions,current_setting('transaction_read_only')='on' read_only;
rollback;
