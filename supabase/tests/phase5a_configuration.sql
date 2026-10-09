-- Finite Game Center configuration is independent of Game Center activation.
-- All records/claims are disposable synthetic fixture data; rollback at end.
begin;
\ir phase5a/fixture.sql
create temp table phase5a_module_baseline as
 select om.*,om.version as original_version from public.organization_modules om
 join public.modules m on m.id=om.module_id
 where om.organization_id=pg_temp.f('org') and m.key='sports';
update public.organization_modules set configuration=configuration||'{"fixture_preserved":{"finite_marker":true}}'::jsonb
 where id=(select id from phase5a_module_baseline);
create temp table phase5a_configuration_state(version bigint not null);
insert into phase5a_configuration_state select version from public.organization_modules where id=(select id from phase5a_module_baseline);
create temp table phase5a_configuration_receipts(label text primary key,request_id uuid not null,command jsonb not null,result jsonb not null);
grant select,update on phase5a_configuration_state to authenticated;
grant select,insert on phase5a_configuration_receipts to authenticated;
grant select on phase5a_module_baseline to authenticated;
create function pg_temp.configuration_command(c jsonb,org uuid default null,v bigint default null) returns jsonb language sql stable as $$
 select pg_temp.cmd('games.configure',jsonb_build_object('organization_id',coalesce(org,pg_temp.f('org')),'expected_version',coalesce(v,(select version from pg_temp.phase5a_configuration_state)),'configuration',c))
$$;
create function pg_temp.configure(label text,c jsonb) returns jsonb language plpgsql as $$declare command jsonb;result jsonb;request uuid;begin
 request:=pg_temp.f('configuration-'||label);command:=pg_temp.configuration_command(c);
 result:=public.boss_games_mutate(request,command);
 insert into pg_temp.phase5a_configuration_receipts values(label,request,command,result);
 update pg_temp.phase5a_configuration_state set version=(result->>'version')::bigint;
 return result;
end$$;
revoke all on function pg_temp.configuration_command(jsonb,uuid,bigint),pg_temp.configure(text,jsonb) from public;
grant execute on function pg_temp.configuration_command(jsonb,uuid,bigint),pg_temp.configure(text,jsonb) to authenticated;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.check('configuration exposes current module version','CONFIGURATION',
 (public.boss_games_read(pg_temp.query())->>'configuration_version')::bigint=(select version from phase5a_configuration_state));
select pg_temp.configure('disable-center','{"game_center":false}');
select pg_temp.check('administrator can configure while Game Center is disabled','CONFIGURATION',
 not(public.boss_games_read(pg_temp.query())->'features'->>'game_center')::boolean
 and(public.boss_games_read(pg_temp.query())->'capabilities'->>'configure')::boolean);
select pg_temp.check('configuration returns organization identity and no fabricated game','CONFIGURATION',
 (select result->'game_id'='null'::jsonb and result->>'organization_id'=pg_temp.f('org')::text from phase5a_configuration_receipts where label='disable-center'));
select pg_temp.check('same disabled-feature configuration request replays under current authority','IDEMPOTENCY',
 (select (public.boss_games_mutate(request_id,command)->>'replayed')::boolean from phase5a_configuration_receipts where label='disable-center'));
select pg_temp.conflict('configuration stale version cannot overwrite current flags',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-stale'),pg_temp.configuration_command('{"game_center":true}',null,(select version-1 from phase5a_configuration_state))));
select pg_temp.denied('future configuration keys cannot activate new functionality',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-future'),pg_temp.configuration_command('{"game_center":true,"full_basketball_scoring":true}')),'PT422');
select pg_temp.denied('configuration booleans must be actual booleans',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-string'),pg_temp.configuration_command('{"game_center":"true"}')),'PT422');
select pg_temp.denied('configuration null cannot clear a flag',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-null'),pg_temp.configuration_command('{"game_operations":null}')),'PT422');
select pg_temp.denied('configuration empty object is rejected',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-empty'),pg_temp.configuration_command('{}')),'PT422');
select pg_temp.denied('configuration arrays are rejected',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-array'),pg_temp.configuration_command('[]')),'PT422');
select pg_temp.denied('configuration version cannot be string-coerced',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-version-string'),pg_temp.configuration_command('{"game_center":true}')||jsonb_build_object('input',
 (pg_temp.configuration_command('{"game_center":true}')->'input')||'{"expected_version":"1"}'::jsonb)),'PT422');
select pg_temp.denied('configuration forged organization UUID denies without creation',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-forged-org'),pg_temp.configuration_command('{"game_center":true}',pg_temp.f('missing-org'),1)));
select pg_temp.denied('configuration other tenant denies before module metadata',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-other-org'),pg_temp.configuration_command('{"game_center":true}',pg_temp.f('other-org'),1)));
select pg_temp.actor('coach');
select pg_temp.denied('exact-team head coach cannot configure organization Game Center',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-coach'),pg_temp.configuration_command('{"game_center":true}')));
select pg_temp.check('coach cannot see configuration capability','CONFIGURATION',
 not(public.boss_games_read(pg_temp.query())->'capabilities'->>'configure')::boolean);
select pg_temp.actor('scorer');
select pg_temp.denied('scorekeeper role cannot configure organization Game Center',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-scorer'),pg_temp.configuration_command('{"game_center":true}')));
select pg_temp.actor('parent');
select pg_temp.denied('guardian relationship cannot configure organization Game Center',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-parent'),pg_temp.configuration_command('{"game_center":true}')));
select pg_temp.actor('other-admin');
select pg_temp.denied('other organization administrator cannot configure target tenant',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-foreign-admin'),pg_temp.configuration_command('{"game_center":true}')));
select pg_temp.actor('admin');
select pg_temp.configure('enable-center','{"game_center":true,"game_operations":true,"public_game_center":true}');
reset role;
select pg_temp.check('configuration merges finite flags and preserves unrelated configuration','CONFIGURATION',
 (select configuration->'fixture_preserved'='{"finite_marker":true}'::jsonb
 and(configuration->>'game_center')::boolean and(configuration->>'public_game_center')::boolean
 and(configuration->>'head_coach_game_management')::boolean from public.organization_modules where id=(select id from phase5a_module_baseline)));
select pg_temp.check('configuration cannot activate or extend a module','CONFIGURATION',
 (select om.status=b.status and om.starts_at=b.starts_at and om.ends_at is not distinct from b.ends_at
 and om.source is not distinct from b.source and om.organization_id=b.organization_id and om.module_id=b.module_id
 from public.organization_modules om join phase5a_module_baseline b on b.id=om.id));
select pg_temp.check('configuration is audited without game ledger or notification work','AUDIT',
 exists(select 1 from public.audit_events where action='games.configure' and organization_id=pg_temp.f('org'))
 and not exists(select 1 from public.games where organization_id=pg_temp.f('org'))
 and not exists(select 1 from public.game_operations where organization_id=pg_temp.f('org')));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.create_game('external','external');
select pg_temp.game_op('game.roster.snapshot','external');
select pg_temp.game_op('game.operator.assign','external',jsonb_build_object('person_id',pg_temp.f('admin'),'role_assignment_id',pg_temp.f('role-admin'),'function_key','game_administrator','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
select pg_temp.game_op('game.start','external');
select pg_temp.configure('disable-operations','{"game_operations":false}');
select pg_temp.denied('feature disable denies already mounted score command',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-disabled-score'),pg_temp.game_command('game.score.set','external','{"primary_score":1,"opponent_score":0}')));
select pg_temp.check('feature disable removes current operator capability','CONFIGURATION',
 (select not(g->'capabilities'->>'operate')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('external'))->'games')g));
select pg_temp.configure('enable-operations','{"game_operations":true}');
reset role;
update public.role_assignments set status='inactive' where id=pg_temp.f('role-admin');
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('configuration receipt replay rechecks current role authority',
 (select format('select public.boss_games_mutate(%L,%L)',request_id,command) from phase5a_configuration_receipts where label='enable-center'));
reset role;
update public.role_assignments set status='active' where id=pg_temp.f('role-admin');
update public.organization_memberships set status='inactive' where organization_id=pg_temp.f('org') and person_id=pg_temp.f('admin');
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('configuration receipt replay rechecks current organization relationship',
 (select format('select public.boss_games_mutate(%L,%L)',request_id,command) from phase5a_configuration_receipts where label='enable-center'));
reset role;
update public.organization_memberships set status='active' where organization_id=pg_temp.f('org') and person_id=pg_temp.f('admin');
update public.organization_modules set status='inactive' where id=(select id from phase5a_module_baseline);
update phase5a_configuration_state set version=(select version from public.organization_modules where id=(select id from phase5a_module_baseline));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('inactive module cannot be activated through configuration',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-inactive'),pg_temp.configuration_command('{"public_game_center":false}')));
select pg_temp.check('inactive module reports no active configuration version','CONFIGURATION',
 (public.boss_games_read(pg_temp.query())->>'configuration_version')::bigint=0);
reset role;
select pg_temp.check('inactive module configuration does not activate entitlement','CONFIGURATION',
 (select status='inactive' from public.organization_modules where id=(select id from phase5a_module_baseline)));
select pg_temp.denied('caller cannot directly rewrite optimistic module version',
 'update public.organization_modules set version=version+1 where id=(select id from phase5a_module_baseline)','23514');
insert into public.organization_modules(id,organization_id,module_id,status,starts_at,ends_at,configuration)
 select pg_temp.f('configuration-future-module'),organization_id,module_id,'active',now()+interval '1 day',now()+interval '2 days',configuration
 from phase5a_module_baseline;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('future Sports assignment cannot be configured',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-future-assignment'),pg_temp.configuration_command('{"public_game_center":false}')));
reset role;
update public.organization_modules set status='active',ends_at=now()-interval '1 hour' where id=(select id from phase5a_module_baseline);
update phase5a_configuration_state set version=(select version from public.organization_modules where id=(select id from phase5a_module_baseline));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('expired Sports assignment cannot be configured',format('select public.boss_games_mutate(%L,%L)',
 pg_temp.f('configuration-expired-assignment'),pg_temp.configuration_command('{"public_game_center":false}')));
reset role;
select count(*) as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
