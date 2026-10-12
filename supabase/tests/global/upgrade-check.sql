begin;
create temp table global_upgrade_assertions(label text);
create function pg_temp.amendment_check(label text,ok boolean)returns void language plpgsql as $$begin if ok is distinct from true then raise exception'Amendment upgrade invariant failed: %',label;end if;insert into global_upgrade_assertions values(label);end$$;
do $$declare t record;n bigint;h text;q text;begin for t in select *from boss_private.global_upgrade_proof order by table_name loop
 q:=format('select to_jsonb(v)%s as row_value from public.%I v %s',case when t.table_name='money_boards'then'-''unit_id'''else''end,t.table_name,
 case t.table_name when'permissions'then'where key<>''fundraising.platform_policy_manage'''when'role_permissions'then'where permission_id not in(select id from public.permissions where key=''fundraising.platform_policy_manage'')'else''end);
 execute 'select count(*),encode(sha256(convert_to(coalesce(string_agg(row_value::text,E''\n''order by row_value::text),''''),''UTF8'')),''hex'')from('||q||')rows'into n,h;
 perform pg_temp.amendment_check('unchanged original populated rowset '||t.table_name,n=t.row_count and h=t.digest);end loop;end$$;
select pg_temp.amendment_check('only new policy permission added',(select count(*)=1 from public.permissions where key='fundraising.platform_policy_manage'));
select pg_temp.amendment_check('only two platform roles get new potential',(select count(*)=2 and bool_and(r.key in('super_administrator','platform_administrator'))from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where p.key='fundraising.platform_policy_manage'));
select pg_temp.amendment_check('historical checkouts are never re-snapshotted',not exists(select 1 from public.fundraising_checkout_snapshots));
select pg_temp.amendment_check('historical sources are never reallocated',not exists(select 1 from public.fundraising_credit_sources)and not exists(select 1 from public.fundraising_cash_rounding_sources));
select pg_temp.amendment_check('original admin access valid',boss_private.fundraising_role(md5('boss-phase7b-test:admin')::uuid,'fundraising.manage',md5('boss-phase7b-test:org')::uuid));
select count(*)passed_assertions,'Populated 123→129 immutable row/financial/Wallet preservation' suite from global_upgrade_assertions;
rollback;
