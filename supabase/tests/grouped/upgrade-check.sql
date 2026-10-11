begin;
create temp table grouped_upgrade_assertions(label text);
create function pg_temp.upgrade_check(label text,ok boolean)returns void language plpgsql as $$begin if ok is distinct from true then raise exception'Grouped upgrade invariant failed: %',label;end if;insert into grouped_upgrade_assertions values(label);end$$;
-- Compare every original public rowset independently, including permissions,
-- financial/Wallet/membership/audit/source rows. No original table is exempt.
do $$declare t record;n bigint;h text;begin for t in select *from boss_private.grouped_upgrade_proof order by table_name loop
 execute format('select count(*),encode(sha256(convert_to(coalesce(string_agg(row_to_json(v)::text,E''\n''order by row_to_json(v)::text),''''),''UTF8'')),''hex'')from public.%I v',t.table_name)into n,h;
 perform pg_temp.upgrade_check('unchanged original table '||t.table_name,n=t.row_count and h=t.digest);end loop;end$$;
select pg_temp.upgrade_check('legacy tile uniquely backfilled',(select count(*)=1 and bool_and(group_id is null and amount_minor=500)from public.money_board_tile_claims));
select pg_temp.upgrade_check('legacy correction exactly attributed',(select count(*)=1 and sum(amount_minor)=101 from public.money_board_tile_corrections));
select pg_temp.upgrade_check('legacy gross preserved and additive net correct',boss_private.fundraising_board_projection((select id from public.money_boards limit 1))->>'raised_minor'='500'and boss_private.fundraising_board_projection((select id from public.money_boards limit 1))->'progress_v2'->>'net_raised_minor'='399');
select pg_temp.upgrade_check('legacy pending ACH survives expired checkout',exists(select 1 from public.payment_checkouts where request_id=md5('boss-phase7b-test:checkout-request-grouped-upgrade-pending')::uuid and expires_at<clock_timestamp()and boss_private.rails_hold(id)));
select pg_temp.upgrade_check('legacy pending tile remains unavailable',not boss_private.money_board_tile_available((select id from public.money_board_tiles where board_id=(select id from public.money_boards limit 1) and ordinal=10)));
select pg_temp.upgrade_check('paid tile remains permanently unavailable',not boss_private.money_board_tile_available((select id from public.money_board_tiles where board_id=(select id from public.money_boards limit 1) and ordinal=5)));
select pg_temp.upgrade_check('new raw table closed',not has_table_privilege('anon','public.money_board_tile_claims','SELECT,INSERT,UPDATE,DELETE'));
select pg_temp.upgrade_check('worker still closed',not has_function_privilege('boss_payment_worker','boss_private.rails_dispatch(uuid)','EXECUTE'));
select count(*)passed_assertions,'Exact populated 119→123 source-row/legacy/pending upgrade' suite from grouped_upgrade_assertions;
rollback;
