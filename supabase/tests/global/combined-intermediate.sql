-- Every frozen proposal's post-commit intermediate boundary, including M1-M4.
DO $$DECLARE t record; f record;BEGIN
 FOR t IN SELECT oid,relname,relrowsecurity FROM pg_class WHERE relnamespace='public'::regnamespace AND relkind='r' AND relname IN('money_board_cart_history','money_board_cart_items','money_board_cart_policies','money_board_carts','money_board_checkout_preparations','money_board_correction_plans','money_board_group_commits','money_board_group_items','money_board_groups','money_board_tile_claims','money_board_tile_corrections','fundraising_allocation_delegations','fundraising_allocation_policies','fundraising_brands','fundraising_campaign_origins','fundraising_cash_rounding_corrections','fundraising_cash_rounding_sources','fundraising_checkout_snapshots','fundraising_credit_entries','fundraising_credit_sources','fundraising_destinations','fundraising_platform_policies','fundraising_wallet_channel_policies') LOOP
  IF NOT t.relrowsecurity THEN RAISE EXCEPTION 'Intermediate RLS disabled: %',t.relname;END IF;
  IF has_table_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR has_table_privilege('authenticated',t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR has_table_privilege('service_role',t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR has_table_privilege('boss_payment_worker',t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN RAISE EXCEPTION 'Intermediate raw-table access: %',t.relname;END IF;
 END LOOP;
 FOR f IN SELECT oid,proname,proowner,proacl,proconfig FROM pg_proc WHERE pronamespace='boss_private'::regnamespace AND (proname LIKE 'money_board_%' OR proname LIKE 'fundraising_%') LOOP
  IF EXISTS(SELECT 1 FROM aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE') THEN RAISE EXCEPTION 'Intermediate PUBLIC helper execution: %',f.proname;END IF;
  IF NOT coalesce(f.proconfig @> ARRAY['search_path=""'],false) THEN RAISE EXCEPTION 'Intermediate unsafe helper search path: %',f.proname;END IF;
 END LOOP;
END$$;
SELECT 'PASS combined intermediate RLS/raw ACL/PUBLIC helper ACL/empty search path' AS intermediate_boundary;
