\set ON_ERROR_STOP on
-- Used only by the private socket disposable runner at the exact 113 baseline.
create schema local_upgrade_probe;
create table local_upgrade_probe.relations as
select c.oid::regclass::text object,jsonb_build_object('rls',c.relrowsecurity,'forced',c.relforcerowsecurity,'acl',c.relacl::text,
 'columns',(select jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'notnull',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid))order by a.attnum)from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped),
 'constraints',(select jsonb_agg(pg_get_constraintdef(oid)order by conname)from pg_constraint where conrelid=c.oid),
 'indexes',(select jsonb_agg(pg_get_indexdef(indexrelid)order by indexrelid::regclass::text)from pg_index where indrelid=c.oid),
 'policies',(select jsonb_agg(jsonb_build_object('name',polname,'cmd',polcmd,'roles',polroles,'qual',pg_get_expr(polqual,polrelid),'check',pg_get_expr(polwithcheck,polrelid))order by polname)from pg_policy where polrelid=c.oid))definition
from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in('public','boss_private')and c.relkind='r';
create table local_upgrade_probe.functions as select p.oid::regprocedure::text object,pg_get_functiondef(p.oid)definition,p.proacl::text acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','boss_private','boss_calendar_public');
create table local_upgrade_probe.rows(name text primary key,value text);
do $$declare t text;v text;begin for t in select tablename from pg_tables where schemaname='public'loop
 execute format('select md5(coalesce(string_agg(to_jsonb(r)::text,''|''order by to_jsonb(r)::text),''''))from public.%I r',t)into v;insert into local_upgrade_probe.rows values(t,v);end loop;end$$;
