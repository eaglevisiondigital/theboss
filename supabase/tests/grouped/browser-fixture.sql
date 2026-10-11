-- Synthetic local-only board. The enclosing disposable database is destroyed.
begin;
\ir ../phase7a/fixture.sql
select pg_temp.actor('admin');
select pg_temp.fm('board.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board')),'title','Synthetic Falcons Money Board','goal_minor',1000000,'start_minor',100,'increment_minor',100,'tile_count',5000,'reservation_seconds',600,'visibility','public'));
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board'))));
commit;
