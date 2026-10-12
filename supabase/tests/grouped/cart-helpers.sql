create function pg_temp.cart(a text,cap text,extra jsonb default '{}'::jsonb,req uuid default gen_random_uuid())returns jsonb language sql as $$
 select public.boss_money_board_cart(jsonb_build_object('action',a,'request_id',req,'input',jsonb_build_object('path',pg_temp.fpath('share'))||extra),cap)$$;
grant execute on function pg_temp.cart(text,text,jsonb,uuid)to anon,authenticated;
create function pg_temp.tile(n int)returns uuid language sql security definer set search_path='' as $$select id from public.money_board_tiles where board_id=pg_temp.fid('board')and generation_id=(select id from public.money_board_generations where board_id=pg_temp.fid('board')order by generation desc limit 1)and ordinal=n$$;
grant execute on function pg_temp.tile(int)to anon,authenticated;
create temp table group_results(label text primary key,data jsonb);grant all on group_results to anon,authenticated;
