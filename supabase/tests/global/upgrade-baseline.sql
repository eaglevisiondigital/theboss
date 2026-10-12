create table boss_private.global_upgrade_proof(table_name text primary key,row_count bigint,digest text);
revoke all on boss_private.global_upgrade_proof from public,anon,authenticated,service_role,boss_payment_worker;
alter table boss_private.global_upgrade_proof enable row level security;
do $$declare t record;begin for t in select relname from pg_class where relnamespace='public'::regnamespace and relkind='r'loop
 execute format('insert into boss_private.global_upgrade_proof select %L,count(*),encode(sha256(convert_to(coalesce(string_agg(to_jsonb(v)::text,E''\n''order by to_jsonb(v)::text),''''),''UTF8'')),''hex'')from public.%I v',t.relname,t.relname);
end loop;end$$;
