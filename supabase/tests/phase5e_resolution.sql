begin;
\ir phase5e/fixture.sql
create function pg_temp.vv_scope(scope text,preset text,extra jsonb default'{}')returns void language plpgsql as $$begin
 perform public.boss_games_mutate(gen_random_uuid(),pg_temp.cmd('tracking.profile.set',jsonb_build_object('sport_key','volleyball','scope_type',scope,'expected_profile_version',0,'preset',preset,'reason','Synthetic exact inheritance')||extra));end$$;
grant execute on function pg_temp.vv_scope(text,text,jsonb)to authenticated;
set local role authenticated;select pg_temp.actor('admin');select pg_temp.ff_link('chain','internal','falcons','volleyball');
select pg_temp.vv_scope('organization','essential',jsonb_build_object('organization_id',pg_temp.f('org')));
reset role;
select pg_temp.check('organization resolves','SCOPE',(select boss_private.tracking_resolve(g,'primary')->'selection'->>'preset'='essential'from public.games g where g.id=pg_temp.ff_game('chain')));
set local role authenticated;select pg_temp.vv_scope('organization_unit','full',jsonb_build_object('organization_id',pg_temp.f('org'),'unit_id',pg_temp.f('unit')));
reset role;
select pg_temp.check('exact direct unit overrides org','SCOPE',(select boss_private.tracking_resolve(g,'primary')->'selection'->>'preset'='full'from public.games g where g.id=pg_temp.ff_game('chain')));
set local role authenticated;select pg_temp.vv_scope('team','score_only',jsonb_build_object('organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons')));
reset role;
select pg_temp.check('exact team overrides direct unit','SCOPE',(select boss_private.tracking_resolve(g,'primary')->'selection'->>'preset'='score_only'from public.games g where g.id=pg_temp.ff_game('chain')));
select pg_temp.check('opponent does not inherit primary team profile','SCOPE',(select boss_private.tracking_resolve(g,'opponent')->'selection'->>'preset'='full'from public.games g where g.id=pg_temp.ff_game('chain')));
set local role authenticated;select pg_temp.vv_scope('season','standard',jsonb_build_object('organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'),'season_id',pg_temp.f('season')));
reset role;
select pg_temp.check('matching team-season overrides team','SCOPE',(select boss_private.tracking_resolve(g,'primary')->'selection'->>'preset'='standard'from public.games g where g.id=pg_temp.ff_game('chain')));
set local role authenticated;select pg_temp.vv_profile('chain','primary','custom','["digs"]','["digs"]');
reset role;
select pg_temp.check('game side overrides all applicable scopes','SCOPE',(select boss_private.tracking_resolve(g,'primary')->'selection'->'quick'='["digs"]'from public.games g where g.id=pg_temp.ff_game('chain')));
select pg_temp.check('ordered provenance includes five exact contexts','SCOPE',(select boss_private.tracking_resolve(g,'primary')->'provenance'->0->>'scope_type'='organization'and jsonb_array_length(boss_private.tracking_resolve(g,'primary')->'provenance')=5 from public.games g where g.id=pg_temp.ff_game('chain')));
-- Platform default requires actual mapped platform games.manage, never an org administrator.
set local role authenticated;select pg_temp.denied('org administrator cannot set platform default','select pg_temp.vv_scope(''platform'',''full'')');
select pg_temp.actor('program');
select pg_temp.denied('program cannot manage sibling unit',format('select pg_temp.vv_scope(''organization_unit'',''essential'',%L::jsonb)',jsonb_build_object('organization_id',pg_temp.f('org'),'unit_id',pg_temp.f('sibling-unit'))));
reset role;
-- Descendant settings receive no inherited unit configuration.
insert into public.organization_units(id,organization_id,parent_unit_id,unit_type,name,slug)values(pg_temp.f('descendant'),pg_temp.f('org'),pg_temp.f('unit'),'program','Synthetic child unit','synthetic-child-unit');
insert into public.teams(id,organization_id,parent_unit_id,name,slug,status,visibility)values(pg_temp.f('descendant-team'),pg_temp.f('org'),pg_temp.f('descendant'),'Synthetic descendant team','synthetic-descendant-team','active','member');
select pg_temp.check('no implicit descendant setting inheritance','SCOPE',(select boss_private.tracking_resolve(jsonb_populate_record(g,jsonb_build_object('opponent_team_id',pg_temp.f('descendant-team'))),'opponent')->'selection'->>'preset'='essential'from public.games g where g.id=pg_temp.ff_game('chain')));
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
