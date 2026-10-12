-- Synthetic local-only board. The enclosing disposable database is destroyed.
begin;
\ir ../phase7a/fixture.sql
select pg_temp.actor('admin');
select pg_temp.fm('board.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board')),'title','Synthetic Falcons Money Board','goal_minor',1000000,'start_minor',100,'increment_minor',100,'tile_count',5000,'reservation_seconds',600,'visibility','public'));
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board'))));


-- Additional native organization/ministry routes use the same isolated fixture.
create function pg_temp.am(a text,i jsonb)returns jsonb language sql as $$select public.boss_fundraising_allocation_mutate(jsonb_build_object('action',a,'request_id',gen_random_uuid(),'input',i))$$;
select pg_temp.fm('campaign.create',jsonb_build_object('organization_id',pg_temp.f('org'),'name','Synthetic ministry native acceptance','currency','USD','goal_minor',10000000,'starts_at',now()-interval'1 day','ends_at',now()+interval'30 days','scope','organization','channels',jsonb_build_array('money_board','direct_support')),'native-ministry');
select pg_temp.fm('campaign.publish',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'expected_version',1));
do $$declare b uuid;d uuid;begin
 b:=(pg_temp.am('unit_board.create',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'unit_id',pg_temp.f('sibling-unit'),'title','Synthetic ministry Money Board','goal_minor',700000,'start_minor',100,'increment_minor',100,'tile_count',50,'visibility','public'))->>'id')::uuid;
 perform pg_temp.fm('board.generate',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'board_id',b,'expected_version',1));
 perform pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'board_id',b,'expected_version',2));
 d:=(pg_temp.am('destination.create',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'kind','ministry','unit_id',pg_temp.f('sibling-unit'),'board_id',b,'goal_minor',700000,'referrer_person_id',pg_temp.f('admin')))->>'id')::uuid;
 perform pg_temp.am('destination.publish',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'destination_id',d));
 d:=(pg_temp.am('destination.create',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'kind','organization','goal_minor',10000000))->>'id')::uuid;
 perform pg_temp.am('destination.publish',jsonb_build_object('campaign_id',pg_temp.fid('native-ministry'),'destination_id',d));
end$$;
update public.organization_modules set status='inactive'where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key in('sports','calendar','boss_bucks'));
commit;
