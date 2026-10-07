-- Closed raw resources and current identity/exact-game/resource authorization.
begin;
\ir phase5d/fixture.sql
do $$declare t record;client text;fn record;begin
 perform pg_temp.check('Football adds no broad roles/permissions/modules','CATALOG',(select count(*)=21 from public.roles WHERE key <> 'competition_manager')and(select count(*)=59 from public.permissions WHERE key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage','boss_bucks.payment_reverse','payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile'))and(select count(*)=446 from public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage','boss_bucks.payment_reverse','payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile'))and(select count(*)=14 from public.modules where key <> 'payments'));
 perform pg_temp.check('exact five raw Football tables','CATALOG',(select count(*)=5 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relkind='r'and c.relname like 'game_football_%'));
 for t in select c.oid,c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relkind='r'and c.relname like 'game_football_%'loop
  perform pg_temp.check(t.relname||' closed RLS','RLS',t.relrowsecurity and not exists(select 1 from pg_policy where polrelid=t.oid));
  foreach client in array array['anon','authenticated','service_role']loop perform pg_temp.check(t.relname||' closed '||client,'RLS',not has_table_privilege(client,t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));end loop;
 end loop;
 for fn in select p.*,p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like 'football_%'loop
  perform pg_temp.check(fn.signature||' fixed search path','RPC',coalesce('search_path=""'=any(fn.proconfig),false));
  perform pg_temp.check(fn.signature||' no PUBLIC execute','RPC',not exists(select 1 from aclexplode(coalesce(fn.proacl,acldefault('f',fn.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE'));
  foreach client in array array['anon','authenticated','service_role']loop perform pg_temp.check(fn.signature||' private '||client,'RPC',not has_function_privilege(client,fn.oid,'EXECUTE'));end loop;
 end loop;
end$$;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('authority');
select pg_temp.ff_link('unrelated','wildcats','wildcats');
select pg_temp.ff_link('sibling','sibling','tigers');
select pg_temp.game_op('game.operator.assign','authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',clock_timestamp()+interval '1 hour'));
select pg_temp.state_denied('manual score cannot override Football ownership',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-manual'),pg_temp.game_command('game.score.set','authority','{"primary_score":999,"opponent_score":0}')));
select pg_temp.state_denied('configured Football snapshot cannot refresh',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-roster-refresh'),pg_temp.game_command('game.roster.snapshot','authority')));
do $$declare field text;value jsonb;begin
 for field,value in select * from(values('points','999'::jsonb),('actor_person_id',to_jsonb(pg_temp.f('other-admin'))),('organization_id',to_jsonb(pg_temp.f('other-org'))),('period_number','4'::jsonb),('clock_ms','0'::jsonb),('engine_version','"forged"'::jsonb),('roster_revision','999'::jsonb))v(field,value)loop
  perform pg_temp.state_denied('Football server field injection '||field,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-inject-'||field),pg_temp.game_command('football.play.add','authority',jsonb_build_object('play_type','rush','side','primary','yards',1,field,value))));
 end loop;
 for field,value in select * from(values('play_type','null'::jsonb),('side','"visiting"'::jsonb),('yards','1.5'::jsonb),('yards','101'::jsonb),('return_yards','-1'::jsonb),('roster_id','"not-a-uuid"'::jsonb),('made','"true"'::jsonb))v(field,value)loop
  perform pg_temp.state_denied('Football malformed input '||field||'/'||value,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-malformed-'||field||value::text),pg_temp.game_command('football.play.add','authority','{"play_type":"rush","side":"primary","yards":1}'::jsonb||jsonb_build_object(field,value))));
 end loop;
end$$;
select pg_temp.state_denied('unknown Football play type fails closed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-unknown'),pg_temp.game_command('football.play.add','authority','{"play_type":"manual_score","side":"primary"}')));
select pg_temp.state_denied('nonrostered Football actor denied',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-forged-roster'),pg_temp.game_command('football.play.add','authority',jsonb_build_object('play_type','rush','side','primary','yards',1,'roster_id',pg_temp.f('unknown-roster')))));
select pg_temp.state_denied('opponent actor cannot rush for primary',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-wrong-side'),pg_temp.game_command('football.play.add','authority',jsonb_build_object('play_type','rush','side','primary','yards',1,'roster_id',pg_temp.ff_roster('authority','opponent',2)))));
select pg_temp.state_denied('offensive player cannot receive defensive sack attribution',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-defender-side'),pg_temp.game_command('football.play.add','authority',jsonb_build_object('play_type','sack','side','primary','yards',-1,'roster_id',pg_temp.ff_roster('authority','primary',1),'defender_roster_id',pg_temp.ff_roster('authority','primary',5)))));
select pg_temp.actor('scorer');
select pg_temp.ff_play('authority','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('authority','primary',2),'yards',1),'scorer-positive');
select pg_temp.denied('exact Falcons operator cannot attribute private opposing athlete',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-private-opponent'),pg_temp.game_command('football.play.add','authority',jsonb_build_object('play_type','rush','side','primary','roster_id',pg_temp.ff_roster('authority','primary',2),'tackler_roster_id',pg_temp.ff_roster('authority','opponent',5),'yards',1))));
select pg_temp.denied('operator cannot control unrelated team game',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-unrelated'),pg_temp.game_command('football.period.start','unrelated')));
select pg_temp.denied('operator cannot control sibling unit game',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-sibling'),pg_temp.game_command('football.period.start','sibling')));
select pg_temp.denied('scorekeeper cannot correct Football',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-scorekeeper-reverse'),pg_temp.game_command('football.play.reverse','authority',jsonb_build_object('event_id',pg_temp.ff_event_id('authority','scorer-positive'),'reason','Synthetic unauthorized correction'))));
select pg_temp.denied('scorekeeper cannot reopen Football',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-scorekeeper-reopen'),pg_temp.game_command('game.reopen','authority','{"reason":"Synthetic unauthorized reopen"}')));
select pg_temp.actor('coach');
select pg_temp.denied('coach role alone grants no Football scoring',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-coach'),pg_temp.game_command('football.play.add','authority','{"play_type":"rush","side":"primary","yards":1}')));
select pg_temp.actor('other-admin');
select pg_temp.denied('cross-tenant Football mutation denied',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-other-tenant'),pg_temp.game_command('football.play.add','authority','{"play_type":"rush","side":"primary","yards":1}')));
select pg_temp.actor('parent');
select pg_temp.check('family strips entry roster/control/final epochs','PROJECTION',jsonb_array_length(pg_temp.ff_detail('authority','{"view":"family"}')->'entry_roster')=0 and jsonb_array_length(pg_temp.ff_detail('authority','{"view":"family"}')->'entry_plays')=0 and jsonb_array_length(pg_temp.ff_detail('authority','{"view":"family"}')->'final_epochs')=0 and not(pg_temp.ff_detail('authority','{"view":"family"}')->'capabilities'->>'operate')::boolean);
select pg_temp.check('family safe player scope intersects child only','PROJECTION',jsonb_array_length(pg_temp.ff_detail('authority','{"view":"family"}')->'players')=1);
select pg_temp.check('family omits raw provenance and private audit','PROJECTION',pg_temp.ff_detail('authority','{"view":"family"}')::text!~'actor_person_id|participant_id|person_id|guardian|attendance_reason|correction_of|clock_anchor');
select pg_temp.actor('household-only');
select pg_temp.denied('household without guardian authority cannot read family Football',format('select public.boss_games_read(%L)',pg_temp.query('authority','{"view":"family"}')));
reset role;
do $$declare flag text;begin
 foreach flag in array array['football_live_scoring','football_stats','game_operations']loop
  update public.organization_modules set configuration=jsonb_set(configuration,array[flag],'false')where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
  set local role authenticated;perform pg_temp.actor('admin');
  perform pg_temp.denied('disabled '||flag||' blocks mounted Football command',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-disabled-'||flag),pg_temp.game_command('football.play.add','authority','{"play_type":"rush","side":"primary","yards":1}')));
  perform pg_temp.state_denied('disabled '||flag||' does not restore manual scoring',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-disabled-manual-'||flag),pg_temp.game_command('game.score.set','authority','{"primary_score":999,"opponent_score":0}')));
  perform pg_temp.check('disabled '||flag||' removes private operator context','PROJECTION',jsonb_array_length(pg_temp.ff_detail('authority')->'entry_plays')=0);
  reset role;update public.organization_modules set configuration=jsonb_set(configuration,array[flag],'true')where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
 end loop;
end$$;
update public.organization_modules set configuration=configuration||'{"football_play_by_play":false}'where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('scorer');
select pg_temp.check('PBP disabled preserves private bounded operator context','PROJECTION',jsonb_array_length(pg_temp.ff_detail('authority')->'plays')=0 and jsonb_array_length(pg_temp.ff_detail('authority')->'entry_plays')>0);
reset role;
create temp table ff_retry(command jsonb,request uuid);grant select,insert on ff_retry to authenticated;
set local role authenticated;select pg_temp.actor('scorer');
insert into ff_retry values(pg_temp.game_command('football.play.add','authority','{"play_type":"rush","side":"primary","yards":1}'),pg_temp.f('ff-idempotent-rush'));
select public.boss_games_mutate(request,command)from ff_retry;
select pg_temp.check('retry returns same Football receipt','IDEMPOTENCY',(select(public.boss_games_mutate(request,command)->>'replayed')::boolean from ff_retry));
reset role;
select pg_temp.check('retry creates one Football event and ledger operation','IDEMPOTENCY',(select count(*)=1 from public.game_football_events where request_id=pg_temp.f('ff-idempotent-rush'))and(select count(*)=1 from public.game_operations where request_id=pg_temp.f('ff-idempotent-rush')));
update public.game_operator_assignments set status='ended'where game_id=pg_temp.ff_game('authority')and person_id=pg_temp.f('scorer');
set local role authenticated;select pg_temp.actor('scorer');
select pg_temp.denied('revoked operator cannot replay old accepted receipt', 'select public.boss_games_mutate(request,command)from ff_retry');
reset role;
select pg_temp.check('denied replay retains original single event','IDEMPOTENCY',(select count(*)=1 from public.game_football_events where request_id=pg_temp.f('ff-idempotent-rush')));
set local role anon;select set_config('request.jwt.claims','{}',true);
select pg_temp.denied('anonymous cannot invoke Football canonical mutation',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-anon'),pg_temp.game_command('football.play.add','authority','{"play_type":"rush","side":"primary","yards":1}')),'42501');
reset role;
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
