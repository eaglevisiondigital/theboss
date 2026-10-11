\set ON_ERROR_STOP on
begin;set local statement_timeout='12s';
\ir phase7a/fixture.sql
\ir grouped/cart-helpers.sql
-- Fresh generation before any hold or claim. Source fixture starts with 50 tiles.
select pg_temp.actor('admin');
select pg_temp.fm('board.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board')),'title','Synthetic grouped scale board','reservation_seconds',600,'visibility','public','start_minor',1,'increment_minor',1,'tile_count',100001,'goal_minor',100000000),'scale-board');
-- Generation is already a bounded native 10,000-tile command. Reproduce ten
-- separate native requests; never aggregate their deadlines into one DO block.
select $command$select pg_temp.fm('board.generate',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board'))))$command$from generate_series(1,10) \gexec
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board'))));
reset role;
-- Match the real committed-population planner lifecycle. Rollback fixtures are
-- invisible to background ANALYZE; capture accurate statistics explicitly,
-- as the existing Merchant/Partner performance fixtures already do.
analyze public.money_board_tiles;analyze public.money_board_generations;
analyze public.money_board_carts;analyze public.money_board_cart_items;
analyze public.money_board_groups;analyze public.money_board_group_items;
analyze public.money_board_reservations;analyze public.fundraising_intents;
analyze public.payment_checkouts;analyze public.provider_operations;
create temp table grouped_timings(label text,ms numeric);
do $$declare at_time timestamptz;j jsonb;n int;begin
 at_time:=clock_timestamp();j:=public.boss_money_board_public(pg_temp.fpath('share'),99950);insert into grouped_timings values('late-page',extract(epoch from clock_timestamp()-at_time)*1000);
 perform pg_temp.check('large board finite fifty tiles','SCALE',jsonb_array_length(j->'tiles')=50);
 perform pg_temp.check('late page canonical ordinal','SCALE',j->'tiles'->0->>'ordinal'='99951');
 perform pg_temp.check('large board counts exact','SCALE',j->'progress'->>'available_count'='100001');
 at_time:=clock_timestamp();j:=public.boss_money_board_candidate(pg_temp.fpath('share'));insert into grouped_timings values('spin',extract(epoch from clock_timestamp()-at_time)*1000);
 perform pg_temp.check('spin canonical and bounded','SCALE',(j->'candidate'->>'ordinal')::int between 1 and 100001);
 end$$;
select pg_temp.cart('open',repeat('a',64));
-- Native selection issues one command per click. Keep each original 12s
-- statement deadline; do not pack fifty independent commands under one clock.
create function pg_temp.timed_grouped_add(n int)returns void language plpgsql as $$declare at_time timestamptz:=clock_timestamp();begin perform pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(n)));insert into grouped_timings values('add-'||n,extract(epoch from clock_timestamp()-at_time)*1000);end$$;
select format('select pg_temp.timed_grouped_add(%s)',n)from generate_series(1,50)n \gexec
analyze public.money_board_cart_items;
do $$declare at_time timestamptz;j jsonb;begin
 perform pg_temp.check('fifty across finite projections allowed','LIMIT',jsonb_array_length(pg_temp.cart('read',repeat('a',64))->'items')=50);
 perform pg_temp.denied('fifty-one denied by current configured count','select pg_temp.cart(''add'',repeat(''a'',64),jsonb_build_object(''tile_id'',pg_temp.tile(51)))','PT422');
 at_time:=clock_timestamp();j:=pg_temp.cart('reserve',repeat('a',64));set constraints all immediate;insert into grouped_timings values('reserve-50-and-proof',extract(epoch from clock_timestamp()-at_time)*1000);
 perform pg_temp.check('fifty group principal exact integer','SCALE',j->>'subtotal_minor'='1275');
 end$$;
select *from grouped_timings order by ms desc;
select pg_temp.check('local bounded page/spin/reserve under three seconds','PERFORMANCE',(select bool_and(ms<3000)from grouped_timings));
select pg_temp.conflict('numeric overflow cannot construct board',format('select pg_temp.fm(%L,%L::jsonb)','board.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board')),'title','Synthetic grouped scale board','reservation_seconds',600,'visibility','public','start_minor',1000000000000,'increment_minor',1000000000000,'tile_count',2147483647,'goal_minor',1000000000000))); 
select count(*)passed_assertions,'Grouped large-board pagination, limits and timing' suite from pg_temp.phase5a_assertions;
select *from grouped_timings;
rollback;
