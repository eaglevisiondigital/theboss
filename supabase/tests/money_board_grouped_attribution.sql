\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7a/fixture.sql
select pg_temp.actor('admin');
select pg_temp.fm('board.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'title','Synthetic organization board','goal_minor',10000,'start_minor',100,'increment_minor',100,'tile_count',2,'visibility','public'),'organization-board');
select pg_temp.fm('board.generate',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('organization-board'),'expected_version',1));
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('organization-board'),'expected_version',2));
select pg_temp.fm('board.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'team_id',pg_temp.f('falcons'),'title','Synthetic team board','goal_minor',10000,'start_minor',100,'increment_minor',100,'tile_count',2,'visibility','public'),'team-board');
select pg_temp.fm('board.generate',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('team-board'),'expected_version',1));
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('team-board'),'expected_version',2));
create function pg_temp.scoped_cart(label text,a text,extra jsonb default '{}')returns jsonb language sql as $$select public.boss_money_board_cart(jsonb_build_object('action',a,'request_id',gen_random_uuid(),'input',jsonb_build_object('path',(select public_path from public.money_boards where id=pg_temp.fid(label)))||extra),md5(label)||md5('scope'||label))$$;
select pg_temp.scoped_cart('organization-board','open');
select pg_temp.scoped_cart('organization-board','add',jsonb_build_object('tile_id',(select id from public.money_board_tiles where board_id=pg_temp.fid('organization-board')and ordinal=1)));
select pg_temp.denied('real unrelated board tile cannot enter cart',format('select pg_temp.scoped_cart(%L,%L,%L::jsonb)','organization-board','add',jsonb_build_object('tile_id',(select id from public.money_board_tiles where board_id=pg_temp.fid('team-board')and ordinal=1))),'PT404');
select pg_temp.scoped_cart('organization-board','reserve');
select pg_temp.scoped_cart('organization-board','prepare','{"display_name":"Synthetic organization supporter","anonymous":true}');
select pg_temp.check('organization context never becomes a team source','ATTRIBUTION',exists(select 1 from public.fundraising_intents where source_kind='organization_campaign'and fundraiser_id is null and share_id is null and provenance->>'board_id'=pg_temp.fid('organization-board')::text and provenance->>'team_id'is null));
select pg_temp.check('organization cart has no fictitious team context','ATTRIBUTION',not exists(select 1 from public.money_board_carts where board_id=pg_temp.fid('organization-board')and context?'team_id'));
select pg_temp.scoped_cart('team-board','open');
select pg_temp.scoped_cart('team-board','add',jsonb_build_object('tile_id',(select id from public.money_board_tiles where board_id=pg_temp.fid('team-board')and ordinal=1)));
select pg_temp.scoped_cart('team-board','reserve');
select pg_temp.scoped_cart('team-board','prepare','{"display_name":"Synthetic team supporter","anonymous":true}');
select pg_temp.check('team attribution retains exact Falcons context','ATTRIBUTION',exists(select 1 from public.fundraising_intents where source_kind='team_campaign'and fundraiser_id is null and provenance->>'team_id'=pg_temp.f('falcons')::text and provenance->>'board_id'=pg_temp.fid('team-board')::text));
select pg_temp.check('both roots retain exact organization/currency','ATTRIBUTION',(select count(*)=2 and bool_and(currency='USD'and provenance->>'organization_id'=pg_temp.f('org')::text)from public.fundraising_intents));
set constraints all immediate;
select count(*)passed_assertions,'Grouped organization/team attribution and actual wrong-board denial' suite from pg_temp.phase5a_assertions;
rollback;
