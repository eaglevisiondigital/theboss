do $$declare t record;proc_row record;begin
 for t in select oid,relname,relrowsecurity from pg_class where relnamespace='public'::regnamespace and relkind='r'and relname in('fundraising_brands','fundraising_campaign_origins','fundraising_destinations','fundraising_platform_policies','fundraising_allocation_delegations','fundraising_allocation_policies','fundraising_wallet_channel_policies','fundraising_checkout_snapshots','fundraising_credit_sources','fundraising_credit_entries','fundraising_cash_rounding_sources','fundraising_cash_rounding_corrections')loop
  if not t.relrowsecurity or has_table_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,DELETE')or has_table_privilege('authenticated',t.oid,'SELECT,INSERT,UPDATE,DELETE')or has_table_privilege('service_role',t.oid,'SELECT,INSERT,UPDATE,DELETE')or has_table_privilege('boss_payment_worker',t.oid,'SELECT,INSERT,UPDATE,DELETE')then raise exception'Unsafe intermediate table boundary: %',t.relname;end if;
 end loop;
 for proc_row in select p.oid,p.proname from pg_proc p where p.pronamespace='boss_private'::regnamespace and p.proname like'fundraising_%'loop
  if exists(select 1 from aclexplode(coalesce((select proacl from pg_proc where oid=proc_row.oid),acldefault('f',(select proowner from pg_proc where oid=proc_row.oid))))a where a.grantee=0 and a.privilege_type='EXECUTE')then raise exception'Unsafe intermediate function boundary: %',proc_row.proname;end if;
 end loop;
end$$;
select 'PASS intermediate deny-by-default RLS/ACL';
