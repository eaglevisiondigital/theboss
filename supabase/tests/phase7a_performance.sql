\set ON_ERROR_STOP on
begin;
set local statement_timeout='8s';
\ir phase7a/fixture.sql
create temp table board_performance(tile_count integer,generate_ms numeric,public_read_ms numeric,response_bytes integer);
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.fm('campaign.create',jsonb_build_object('organization_id',pg_temp.f('org'),'name','Synthetic large board','currency','USD','goal_minor',1000000,'starts_at',now()-interval'1 day','ends_at',now()+interval'30 days','scope','organization','channels',jsonb_build_array('money_board')),'large-campaign');
select pg_temp.fm('board.create',jsonb_build_object('campaign_id',pg_temp.fid('large-campaign'),'title','Synthetic scale board','goal_minor',1000000,'start_minor',100,'increment_minor',100,'tile_count',100000,'visibility','public'),'large-board');
reset role;
grant all on board_performance to authenticated,anon;
set local role authenticated;
do $$declare at timestamptz:=clock_timestamp();n int;begin for n in 1..10 loop perform pg_temp.fm('board.generate',jsonb_build_object('campaign_id',pg_temp.fid('large-campaign'),'board_id',pg_temp.fid('large-board'),'expected_version',n));end loop;insert into board_performance(tile_count,generate_ms)values(100000,extract(epoch from clock_timestamp()-at)*1000);end$$;
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('large-campaign'),'board_id',pg_temp.fid('large-board'),'expected_version',11));
select pg_temp.fm('campaign.publish',jsonb_build_object('campaign_id',pg_temp.fid('large-campaign'),'expected_version',1));reset role;
update fundraising_ids set path=(select public_path from public.fundraising_campaigns where id=pg_temp.fid('large-campaign'))where label='large-campaign';
set local role anon;
do $$declare at timestamptz:=clock_timestamp();result jsonb;begin result:=public.boss_fundraising_public(pg_temp.fpath('large-campaign'));update board_performance set public_read_ms=extract(epoch from clock_timestamp()-at)*1000,response_bytes=octet_length(result::text);perform pg_temp.check('large board public page limited to 100 tiles','PERFORMANCE',jsonb_array_length(result->'board'->'tiles')=100);perform pg_temp.check('large preview explicit sum','PERFORMANCE',(result->'board'->>'all_claimed_minor')::bigint=500005000000);perform pg_temp.check('large page no internal IDs','PERFORMANCE',result::text!~'(_id|email|household|date_of_birth)');end$$;
select pg_temp.check('large board cursor last page','PERFORMANCE',jsonb_array_length(public.boss_fundraising_public(pg_temp.fpath('large-campaign'),99900)->'board'->'tiles')=100);reset role;
select pg_temp.check('large generation under request ceiling','PERFORMANCE',(select generate_ms<8000 from board_performance));
select pg_temp.check('large public page below 100KB','PERFORMANCE',(select response_bytes<100000 from board_performance));
select pg_temp.check('large public page under 1s','PERFORMANCE',(select public_read_ms<1000 from board_performance));
select count(*)passed_assertions from pg_temp.phase5a_assertions;
select *from board_performance;
rollback;
