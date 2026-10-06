-- Basketball uses the existing current identity, resource and operator boundary.
begin;
\ir phase5b/fixture.sql
do $$declare t record;client text;f record;begin
 perform pg_temp.check('basketball creates no new broad role permission or module','CATALOG',(select count(*)=21 from public.roles WHERE key <> 'competition_manager') and (select count(*)=59 from public.permissions WHERE key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish')) and (select count(*)=446 from public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish')) and (select count(*)=14 from public.modules));
 for t in select c.oid,c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname like 'game_basketball_%' loop
  perform pg_temp.check(t.relname||' RLS enabled','RLS',t.relrowsecurity);
  perform pg_temp.check(t.relname||' raw policies remain closed','RLS',not exists(select 1 from pg_policy where polrelid=t.oid));
  foreach client in array array['anon','authenticated','service_role'] loop
   perform pg_temp.check(t.relname||' raw closed '||client,'RLS',not has_table_privilege(client,t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));
  end loop;
 end loop;
 for f in select p.oid,p.oid::regprocedure signature,p.proconfig,p.proacl,p.proowner from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'basketball_%' loop
  perform pg_temp.check(f.signature||' fixed search path','RPC',coalesce('search_path=""'=any(f.proconfig),false));
  perform pg_temp.check(f.signature||' no PUBLIC execute','RPC',not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE'));
  foreach client in array array['anon','authenticated','service_role'] loop
   perform pg_temp.check(f.signature||' private closed '||client,'RPC',not has_function_privilege(client,f.oid,'EXECUTE'));
  end loop;
 end loop;
end$$;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.bb_create('bb-authority','internal');
select pg_temp.create_game('wrong-sport','external','falcons','football');
select pg_temp.game_op('game.roster.snapshot','wrong-sport');
select pg_temp.create_game('bb-unrelated','wildcats','wildcats');
select pg_temp.game_op('game.roster.snapshot','bb-unrelated');
select pg_temp.game_op('game.operator.assign','bb-authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
select pg_temp.state_denied('basketball configure rejects explicit football sport',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('wrong-sport-engine'),pg_temp.game_command('basketball.configure','wrong-sport','{"regulation_periods":2,"period_seconds":60,"overtime_seconds":60,"lineup_size":5,"enforce_lineup":false}')));
select pg_temp.state_denied('engine score cannot be silently overwritten manually',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('manual-engine-score'),pg_temp.game_command('game.score.set','bb-authority','{"primary_score":100,"opponent_score":0}')));
select pg_temp.state_denied('configured snapshot cannot be refreshed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('configured-refresh'),pg_temp.game_command('game.roster.snapshot','bb-authority')));
do $$declare field text;value jsonb;begin
 for field,value in select * from(values
 ('points','999'::jsonb),('actor_person_id',to_jsonb(pg_temp.f('other-admin'))),('organization_id',to_jsonb(pg_temp.f('other-org'))),('period_number','4'::jsonb),('clock_ms','0'::jsonb),('roster_revision','999'::jsonb),('engine_version','"forged"'::jsonb)
 )v(field,value) loop
  perform pg_temp.state_denied('server field injection denied '||field,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('inject-'||field),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('bb-authority','primary',1),field,value))));
 end loop;
end$$;
do $$declare field text;value jsonb;begin
 for field,value in select * from(values('event_type','null'::jsonb),('side','null'::jsonb),('roster_id','null'::jsonb),('roster_id','"not-a-uuid"'::jsonb),('side','"visiting"'::jsonb),('event_type','[]'::jsonb),('scoring_event_id','"not-a-uuid"'::jsonb))v(field,value)loop
  perform pg_temp.denied('malformed Basketball field '||field||'/'||value::text,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bad-bb-field-'||field||value::text),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('bb-authority','primary',1))||jsonb_build_object(field,value))),'PT422');
 end loop;
end$$;
select pg_temp.state_denied('unknown play key fails closed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('unknown-play'),pg_temp.game_command('basketball.event.add','bb-authority','{"event_type":"text_score","side":"primary"}')));
select pg_temp.state_denied('forged roster identifier fails closed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('forged-roster'),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.f('not-a-snapshot')))));
select pg_temp.state_denied('opposing roster cannot be attributed to primary side',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('forged-side'),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('bb-authority','opponent',1)))));
select pg_temp.state_denied('enforced lineup rejects bench athlete event',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bench-score'),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('bb-authority','primary',6)))));
do $$declare kind text;begin
 foreach kind in array array['assist','steal','block','personal_foul'] loop
  perform pg_temp.state_denied('player-required event cannot invent attribution '||kind,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('missing-player-'||kind),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type',kind,'side','primary'))));
 end loop;
end$$;
select pg_temp.actor('scorer');
select pg_temp.check('exact operator receives only its six entry identities','PROJECTION',jsonb_array_length(pg_temp.bb_detail('bb-authority')->'entry_roster')=6 and (pg_temp.bb_detail('bb-authority')->'capabilities'->>'operate')::boolean and not(pg_temp.bb_detail('bb-authority')->'capabilities'->>'correct')::boolean);
select pg_temp.bb_event('bb-authority','made_2','primary',1,'scorer-positive');
select pg_temp.denied('exact operator cannot attribute opposing private roster',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-other-side'),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_2','side','opponent','roster_id',pg_temp.bb_roster('bb-authority','opponent',1)))));
select pg_temp.bb_event('bb-authority','made_2','opponent',0,'scorer-unattributed-opponent');
select pg_temp.denied('Falcons operator cannot control unrelated Wildcats game',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-other-game'),pg_temp.game_command('basketball.period.start','bb-unrelated')));
select pg_temp.denied('scorekeeper has no configuration authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-configure'),pg_temp.game_command('basketball.configure','bb-unrelated','{"regulation_periods":2,"period_seconds":60,"overtime_seconds":60,"lineup_size":5,"enforce_lineup":false}')));
select pg_temp.denied('scorekeeper has no elevated sport correction',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-correct'),pg_temp.game_command('basketball.event.reverse','bb-authority',jsonb_build_object('event_id',pg_temp.bb_event_id('bb-authority','scorer-positive'),'reason','Synthetic unapproved correction'))));
select pg_temp.denied('scorekeeper has no reopen authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-reopen'),pg_temp.game_command('game.reopen','bb-authority','{"reason":"Synthetic unapproved reopen"}')));
select pg_temp.actor('coach');
select pg_temp.denied('coach role alone never becomes basketball operator',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('coach-score'),pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('bb-authority','primary',1)))));
select pg_temp.check('coach has no operate capability or entry identities','PROJECTION',not(pg_temp.bb_detail('bb-authority')->'capabilities'->>'operate')::boolean and jsonb_array_length(pg_temp.bb_detail('bb-authority')->'entry_roster')=0);
select pg_temp.actor('other-admin');
select pg_temp.denied('different tenant known basketball resource denied',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('other-tenant-score'),pg_temp.game_command('basketball.event.add','bb-authority','{"event_type":"made_2","side":"primary"}')));
select pg_temp.actor('parent');
select pg_temp.check('family strips entry identity controls and final epochs','PROJECTION',jsonb_array_length(pg_temp.bb_detail('bb-authority','{"view":"family"}')->'entry_roster')=0 and jsonb_array_length(pg_temp.bb_detail('bb-authority','{"view":"family"}')->'final_epochs')=0 and not(pg_temp.bb_detail('bb-authority','{"view":"family"}')->'capabilities'->>'operate')::boolean);
select pg_temp.check('family player totals intersect authorized child snapshot','PROJECTION',jsonb_array_length(pg_temp.bb_detail('bb-authority','{"view":"family"}')->'players')=1);
select pg_temp.check('family basketball fields omit private people and audit data','PROJECTION',pg_temp.bb_detail('bb-authority','{"view":"family"}')::text!~'actor_person_id|participant_id|person_id|guardian|attendance_reason|correction_of|clock_anchor|Synthetic Basketball opponent');
select pg_temp.actor('household-only');
select pg_temp.denied('household alone cannot view family basketball',format('select public.boss_games_read(%L)',pg_temp.query('bb-authority','{"view":"family"}')));
reset role;
update public.role_assignments set status='inactive' where id=pg_temp.f('role-scorer');
set local role authenticated;
select pg_temp.actor('scorer');
select pg_temp.denied('ended mapped role removes basketball entry authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ended-role-score'),pg_temp.game_command('basketball.event.add','bb-authority','{"event_type":"made_2","side":"primary"}')));
reset role;
update public.role_assignments set status='active' where id=pg_temp.f('role-scorer');
update public.team_memberships set status='inactive' where id=pg_temp.f('membership-scorer');
set local role authenticated;
select pg_temp.actor('scorer');
select pg_temp.denied('ended actual team relationship removes basketball authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ended-membership-score'),pg_temp.game_command('basketball.event.add','bb-authority','{"event_type":"made_2","side":"primary"}')));
reset role;
update public.team_memberships set status='active' where id=pg_temp.f('membership-scorer');
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":false}' where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('disabled engine denies mounted event mutation',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('feature-disabled-score'),pg_temp.game_command('basketball.event.add','bb-authority','{"event_type":"made_2","side":"primary"}')));
select pg_temp.state_denied('feature disable cannot unlock manual score bypass',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('feature-disabled-manual'),pg_temp.game_command('game.score.set','bb-authority','{"primary_score":88,"opponent_score":0}')));
reset role;
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":true}' where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
create temp table bb_retry(command jsonb,request uuid);
grant select,insert on bb_retry to authenticated;
set local role authenticated;
select pg_temp.actor('scorer');
insert into bb_retry values(pg_temp.game_command('basketball.event.add','bb-authority',jsonb_build_object('event_type','made_ft','side','primary','roster_id',pg_temp.bb_roster('bb-authority','primary',1))),pg_temp.f('duplicate-free-throw'));
select public.boss_games_mutate(request,command) from bb_retry;
select pg_temp.check('same request retry returns replay receipt','IDEMPOTENCY',(select (public.boss_games_mutate(request,command)->>'replayed')::boolean from bb_retry));
reset role;
select pg_temp.check('same request retry appends exactly one typed event','IDEMPOTENCY',(select count(*)=1 from public.game_basketball_events where game_id=pg_temp.bb_game('bb-authority') and request_id=pg_temp.f('duplicate-free-throw')));
update pg_temp.phase5a_games set version=(select version from public.games where id=pg_temp.bb_game('bb-authority')) where label='bb-authority';
create temp table bb_scorer_assignment as select id from public.game_operator_assignments where game_id=pg_temp.bb_game('bb-authority') and person_id=pg_temp.f('scorer') and status='active';
grant select on bb_scorer_assignment to authenticated;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.game_op('game.operator.end','bb-authority',jsonb_build_object('assignment_id',(select id from bb_scorer_assignment)));
select pg_temp.actor('scorer');
select pg_temp.denied('ended exact assignment denies retained retry',format('select public.boss_games_mutate(%L,%L)',(select request from bb_retry),(select command from bb_retry)));
reset role;
select pg_temp.check('denied replay preserves one original event','IDEMPOTENCY',(select count(*)=1 from public.game_basketball_events where game_id=pg_temp.bb_game('bb-authority') and request_id=pg_temp.f('duplicate-free-throw')));
do $$declare t text;begin
 foreach t in array array['game_basketball_states','game_basketball_events','game_basketball_lineups','game_basketball_lineup_history','game_basketball_finalizations','game_basketball_final_stats'] loop
  set local role anon;
  perform pg_temp.denied('anonymous raw table select denied '||t,format('select * from public.%I',t),'42501');
  reset role;
  set local role authenticated;
  perform pg_temp.denied('authenticated raw table select denied '||t,format('select * from public.%I',t),'42501');
  perform pg_temp.denied('authenticated raw table insert denied '||t,format('insert into public.%I default values',t),'42501');
  reset role;
 end loop;
end$$;
select count(*) as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
