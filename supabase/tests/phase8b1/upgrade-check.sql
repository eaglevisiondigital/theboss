\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
do $$declare t record;v text;current_definition jsonb;begin
 for t in select *from local_upgrade_probe.functions loop
 if pg_get_functiondef(t.object::regprocedure)<>t.definition or (select proacl::text from pg_proc where oid=t.object::regprocedure)is distinct from t.acl then raise exception'Original function changed: %',t.object;end if;end loop;
 for t in select *from local_upgrade_probe.relations loop
 select jsonb_build_object('rls',c.relrowsecurity,'forced',c.relforcerowsecurity,'acl',c.relacl::text,
 'columns',(select jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'notnull',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid))order by a.attnum)from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped),
 'constraints',(select jsonb_agg(pg_get_constraintdef(oid)order by conname)from pg_constraint where conrelid=c.oid),
 'indexes',(select jsonb_agg(pg_get_indexdef(indexrelid)order by indexrelid::regclass::text)from pg_index where indrelid=c.oid),
 'policies',(select jsonb_agg(jsonb_build_object('name',polname,'cmd',polcmd,'roles',polroles,'qual',pg_get_expr(polqual,polrelid),'check',pg_get_expr(polwithcheck,polrelid))order by polname)from pg_policy where polrelid=c.oid))into current_definition from pg_class c where c.oid=t.object::regclass;
 if current_definition is distinct from t.definition then raise exception'Original relation contract changed: %',t.object;end if;end loop;
 for t in select *from local_upgrade_probe.rows loop
 if t.name='permissions'then select md5(coalesce(string_agg(to_jsonb(r)::text,'|'order by to_jsonb(r)::text),''))into v from public.permissions r where key not like'partners.%';
 elsif t.name='role_permissions'then select md5(coalesce(string_agg(to_jsonb(r)::text,'|'order by to_jsonb(r)::text),''))into v from public.role_permissions r where permission_id not in(select id from public.permissions where key like'partners.%');
 else execute format('select md5(coalesce(string_agg(to_jsonb(r)::text,''|''order by to_jsonb(r)::text),''''))from public.%I r',t.name)into v;end if;
 if v<>t.value then raise exception'Original seeded rows changed: %',t.name;end if;end loop;
 if(select count(*)from public.permissions where key like'partners.%')<>6 or(select count(*)from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where p.key like'partners.%')<>12 then raise exception'Finite permission additions mismatch';end if;
end$$;
select(select count(*)from local_upgrade_probe.relations)+(select count(*)from local_upgrade_probe.functions)*2+(select count(*)from local_upgrade_probe.rows)+2 passed_assertions,'Phase 8B1 exact 113-to-119 upgrade preservation'::text suite;
rollback;
