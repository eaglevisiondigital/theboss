-- Soccer uses the existing current identity, resource and operator boundary.
begin;
\ir phase5c/fixture.sql
do $$declare t record;client text;f record;begin
 perform pg_temp.check('soccer creates no new broad role permission or module','CATALOG',(select count(*)=21 from public.roles WHERE key <> 'competition_manager') and (select count(*)=59 from public.permissions WHERE key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve')) and (select count(*)=446 from public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve')) and (select count(*)=14 from public.modules));
 for t in select c.oid,c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname like 'game_soccer_%' loop
  perform pg_temp.check(t.relname||' RLS enabled','RLS',t.relrowsecurity);
  perform pg_temp.check(t.relname||' raw policies remain closed','RLS',not exists(select 1 from pg_policy where polrelid=t.oid));
  foreach client in array array['anon','authenticated','service_role'] loop
   perform pg_temp.check(t.relname||' raw closed '||client,'RLS',not has_table_privilege(client,t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));
  end loop;
 end loop;
 for f in select p.oid,p.oid::regprocedure signature,p.proconfig,p.proacl,p.proowner from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'soccer_%' loop
  perform pg_temp.check(f.signature||' fixed search path','RPC',coalesce('search_path=""'=any(f.proconfig),false));
  perform pg_temp.check(f.signature||' no PUBLIC execute','RPC',not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE'));
  foreach client in array array['anon','authenticated','service_role'] loop
   perform pg_temp.check(f.signature||' private closed '||client,'RPC',not has_function_privilege(client,f.oid,'EXECUTE'));
  end loop;
 end loop;
end$$;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.sc_create('sc-authority','internal');
select pg_temp.create_game('wrong-sport','external','falcons','football');
select pg_temp.game_op('game.roster.snapshot','wrong-sport');
select pg_temp.create_game('sc-unrelated','wildcats','wildcats');
select pg_temp.game_op('game.roster.snapshot','sc-unrelated');
select pg_temp.game_op('game.operator.assign','sc-authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
select pg_temp.state_denied('soccer configure rejects explicit football sport',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('wrong-sport-engine'),pg_temp.game_command('soccer.configure','wrong-sport','{"regulation_segments":2,"segment_seconds":60,"extra_time_segments":0,"extra_time_seconds":60,"lineup_size":11,"enforce_lineup":false,"allow_reentry":true,"max_substitutions":null}')));
select pg_temp.state_denied('engine score cannot be silently overwritten manually',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('manual-engine-score'),pg_temp.game_command('game.score.set','sc-authority','{"primary_score":100,"opponent_score":0}')));
select pg_temp.state_denied('configured snapshot cannot be refreshed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('configured-refresh'),pg_temp.game_command('game.roster.snapshot','sc-authority')));
do $$declare field text;value jsonb;begin
 for field,value in select * from(values
 ('goals','999'::jsonb),('actor_person_id',to_jsonb(pg_temp.f('other-admin'))),('organization_id',to_jsonb(pg_temp.f('other-org'))),('segment_number','4'::jsonb),('clock_ms','0'::jsonb),('roster_revision','999'::jsonb),('engine_version','"forged"'::jsonb)
 )v(field,value) loop
  perform pg_temp.state_denied('server field injection denied '||field,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('inject-'||field),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','goal','side','primary','roster_id',pg_temp.sc_roster('sc-authority','primary',1),field,value))));
 end loop;
end$$;
do $$declare field text;value jsonb;begin
 for field,value in select * from(values('event_type','null'::jsonb),('side','null'::jsonb),('roster_id','null'::jsonb),('roster_id','"not-a-uuid"'::jsonb),('side','"visiting"'::jsonb),('event_type','[]'::jsonb),('scoring_event_id','"not-a-uuid"'::jsonb))v(field,value)loop
  perform pg_temp.denied('malformed Soccer field '||field||'/'||value::text,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bad-sc-field-'||field||value::text),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','goal','side','primary','roster_id',pg_temp.sc_roster('sc-authority','primary',1))||jsonb_build_object(field,value))),'PT422');
 end loop;
end$$;
select pg_temp.state_denied('unknown play key fails closed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('unknown-play'),pg_temp.game_command('soccer.event.add','sc-authority','{"event_type":"text_score","side":"primary"}')));
select pg_temp.state_denied('forged roster identifier fails closed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('forged-roster'),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','goal','side','primary','roster_id',pg_temp.f('not-a-snapshot')))));
select pg_temp.state_denied('opposing roster cannot be attributed to primary side',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('forged-side'),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','goal','side','primary','roster_id',pg_temp.sc_roster('sc-authority','opponent',1)))));
select pg_temp.state_denied('enforced lineup rejects bench athlete event',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bench-score'),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','goal','side','primary','roster_id',pg_temp.sc_roster('sc-authority','primary',12)))));
do $$declare kind text;begin
 foreach kind in array array['assist','second_yellow'] loop
  perform pg_temp.state_denied('player-required event cannot invent attribution '||kind,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('missing-player-'||kind),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type',kind,'side','primary'))));
 end loop;
end$$;
select pg_temp.actor('scorer');
select pg_temp.check('exact operator receives only its twelve entry identities','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority')->'entry_roster')=12 and (pg_temp.sc_detail('sc-authority')->'capabilities'->>'operate')::boolean and not(pg_temp.sc_detail('sc-authority')->'capabilities'->>'correct')::boolean);
select pg_temp.sc_event('sc-authority','goal','primary',1,'scorer-positive');
select pg_temp.denied('exact operator cannot attribute opposing private roster',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-other-side'),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','goal','side','opponent','roster_id',pg_temp.sc_roster('sc-authority','opponent',1)))));
select pg_temp.sc_event('sc-authority','goal','opponent',0,'scorer-unattributed-opponent');
select pg_temp.denied('Falcons operator cannot control unrelated Wildcats game',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-other-game'),pg_temp.game_command('soccer.segment.start','sc-unrelated')));
select pg_temp.denied('scorekeeper has no configuration authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-configure'),pg_temp.game_command('soccer.configure','sc-unrelated','{"regulation_segments":2,"segment_seconds":60,"extra_time_segments":0,"extra_time_seconds":60,"lineup_size":11,"enforce_lineup":false,"allow_reentry":true,"max_substitutions":null}')));
select pg_temp.denied('scorekeeper has no elevated sport correction',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-correct'),pg_temp.game_command('soccer.event.reverse','sc-authority',jsonb_build_object('event_id',pg_temp.sc_event_id('sc-authority','scorer-positive'),'reason','Synthetic unapproved correction'))));
select pg_temp.denied('scorekeeper has no reopen authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('scorer-reopen'),pg_temp.game_command('game.reopen','sc-authority','{"reason":"Synthetic unapproved reopen"}')));
-- Public play-by-play is an independent display flag, not an authorization
-- requirement for the private finite context needed by an assigned operator.
select pg_temp.actor('admin');
select pg_temp.sc_event('sc-authority','goal','opponent',2,'pbp-private-opponent');
reset role;
update public.organization_modules set configuration=configuration||'{"soccer_play_by_play":false}' where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('scorer');
select pg_temp.check('PBP off keeps exact operator accepted goal context private','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority')->'plays')=0 and exists(select 1 from jsonb_array_elements(pg_temp.sc_detail('sc-authority')->'entry_plays')p where p->>'id'=pg_temp.sc_event_id('sc-authority','scorer-positive')::text and (p->>'active')::boolean and p->>'roster_id'=pg_temp.sc_roster('sc-authority','primary',1)::text));
select pg_temp.check('exact Falcons context masks opposing private athlete identity','PROJECTION',exists(select 1 from jsonb_array_elements(pg_temp.sc_detail('sc-authority')->'entry_plays')p where p->>'id'=pg_temp.sc_event_id('sc-authority','pbp-private-opponent')::text and p->>'roster_id' is null and p->>'display_name' is null and p->>'jersey_number' is null));
select pg_temp.sc_event('sc-authority','assist','primary',2,'pbp-off-assist',pg_temp.sc_event_id('sc-authority','scorer-positive'));
select pg_temp.check('PBP off permits authorized assist using accepted context','PROJECTION',exists(select 1 from jsonb_array_elements(pg_temp.sc_detail('sc-authority')->'entry_plays')p where p->>'id'=pg_temp.sc_event_id('sc-authority','pbp-off-assist')::text and p->>'scoring_event_id'=pg_temp.sc_event_id('sc-authority','scorer-positive')::text));
select pg_temp.actor('admin');
select pg_temp.check('PBP off keeps current elevated correction context','PROJECTION',(pg_temp.sc_detail('sc-authority')->'capabilities'->>'correct')::boolean and exists(select 1 from jsonb_array_elements(pg_temp.sc_detail('sc-authority')->'entry_plays')p where p->>'id'=pg_temp.sc_event_id('sc-authority','pbp-private-opponent')::text));
select pg_temp.sc_op('soccer.event.correct','sc-authority',jsonb_build_object('event_id',pg_temp.sc_event_id('sc-authority','pbp-private-opponent'),'event_type','penalty_goal','side','opponent','roster_id',pg_temp.sc_roster('sc-authority','opponent',2),'reason','Synthetic PBP-independent correction'),'pbp-off-correction');
select pg_temp.check('PBP off permits correction and exposes only active finite entry facts','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority')->'plays')=0 and exists(select 1 from jsonb_array_elements(pg_temp.sc_detail('sc-authority')->'entry_plays')p where p->>'id'=pg_temp.sc_event_id('sc-authority','pbp-off-correction')::text and p->>'event_type'='penalty_goal') and not exists(select 1 from jsonb_array_elements(pg_temp.sc_detail('sc-authority')->'entry_plays')p where not(p->>'active')::boolean or p->>'event_type' not in('goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved','own_goal','assist','yellow_card','second_yellow','red_card','foul','keeper_set','substitution')));
select pg_temp.check('list projection never loads private entry contexts','PROJECTION',not exists(select 1 from jsonb_array_elements(public.boss_games_read(pg_temp.query())->'games')g where coalesce(jsonb_array_length(g->'soccer'->'entry_plays'),0)<>0));
reset role;
do $$declare flag text;begin
 foreach flag in array array['soccer_live_scoring','soccer_stats','game_operations']loop
  update public.organization_modules set configuration=jsonb_set(configuration,array[flag],'false') where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
  set local role authenticated;perform pg_temp.actor('admin');
  perform pg_temp.check('disabled '||flag||' closes elevated private entry context','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority')->'entry_plays')=0);
  perform pg_temp.actor('scorer');
  perform pg_temp.check('disabled '||flag||' closes exact operator private entry context','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority')->'entry_plays')=0);
  reset role;
  update public.organization_modules set configuration=jsonb_set(configuration,array[flag],'true') where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
 end loop;
end$$;
set local role authenticated;
select pg_temp.actor('coach');
select pg_temp.denied('coach role alone never becomes soccer operator',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('coach-score'),pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','goal','side','primary','roster_id',pg_temp.sc_roster('sc-authority','primary',1)))));
select pg_temp.check('coach has no operate capability or entry identities','PROJECTION',not(pg_temp.sc_detail('sc-authority')->'capabilities'->>'operate')::boolean and jsonb_array_length(pg_temp.sc_detail('sc-authority')->'entry_roster')=0);
select pg_temp.check('coach role alone receives no private entry play context','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority')->'entry_plays')=0);
select pg_temp.actor('other-admin');
select pg_temp.denied('different tenant known soccer resource denied',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('other-tenant-score'),pg_temp.game_command('soccer.event.add','sc-authority','{"event_type":"goal","side":"primary"}')));
select pg_temp.denied('different tenant cannot read private entry play context',format('select public.boss_games_read(%L)',pg_temp.query('sc-authority')));
select pg_temp.actor('parent');
select pg_temp.check('family strips entry identity controls and final epochs','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority','{"view":"family"}')->'entry_roster')=0 and jsonb_array_length(pg_temp.sc_detail('sc-authority','{"view":"family"}')->'final_epochs')=0 and not(pg_temp.sc_detail('sc-authority','{"view":"family"}')->'capabilities'->>'operate')::boolean);
select pg_temp.check('family player totals intersect authorized child snapshot','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority','{"view":"family"}')->'players')=1);
select pg_temp.check('family soccer fields omit private people and audit data','PROJECTION',pg_temp.sc_detail('sc-authority','{"view":"family"}')::text!~'actor_person_id|participant_id|person_id|guardian|attendance_reason|correction_of|clock_anchor|Synthetic Soccer opponent');
select pg_temp.check('family PBP off never receives private entry play context','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority','{"view":"family"}')->'plays')=0 and jsonb_array_length(pg_temp.sc_detail('sc-authority','{"view":"family"}')->'entry_plays')=0);
select pg_temp.actor('household-only');
select pg_temp.denied('household alone cannot view family soccer',format('select public.boss_games_read(%L)',pg_temp.query('sc-authority','{"view":"family"}')));
reset role;
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.denied('anonymous cannot invoke private operator context RPC',format('select public.boss_games_read(%L)',pg_temp.query('sc-authority')),'42501');
reset role;
update public.organization_modules set configuration=configuration||'{"soccer_play_by_play":true}' where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
update public.role_assignments set status='inactive' where id=pg_temp.f('role-scorer');
set local role authenticated;
select pg_temp.actor('scorer');
select pg_temp.denied('ended mapped role removes soccer entry authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ended-role-score'),pg_temp.game_command('soccer.event.add','sc-authority','{"event_type":"goal","side":"primary"}')));
reset role;
update public.role_assignments set status='active' where id=pg_temp.f('role-scorer');
update public.team_memberships set status='inactive' where id=pg_temp.f('membership-scorer');
set local role authenticated;
select pg_temp.actor('scorer');
select pg_temp.denied('ended actual team relationship removes soccer authority',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ended-membership-score'),pg_temp.game_command('soccer.event.add','sc-authority','{"event_type":"goal","side":"primary"}')));
reset role;
update public.team_memberships set status='active' where id=pg_temp.f('membership-scorer');
update public.organization_modules set configuration=configuration||'{"soccer_live_scoring":false}' where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('disabled engine denies mounted event mutation',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('feature-disabled-score'),pg_temp.game_command('soccer.event.add','sc-authority','{"event_type":"goal","side":"primary"}')));
select pg_temp.state_denied('feature disable cannot unlock manual score bypass',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('feature-disabled-manual'),pg_temp.game_command('game.score.set','sc-authority','{"primary_score":88,"opponent_score":0}')));
reset role;
update public.organization_modules set configuration=configuration||'{"soccer_live_scoring":true}' where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
create temp table sc_retry(command jsonb,request uuid);
grant select,insert on sc_retry to authenticated;
set local role authenticated;
select pg_temp.actor('scorer');
insert into sc_retry values(pg_temp.game_command('soccer.event.add','sc-authority',jsonb_build_object('event_type','penalty_goal','side','primary','roster_id',pg_temp.sc_roster('sc-authority','primary',1))),pg_temp.f('duplicate-penalty'));
select public.boss_games_mutate(request,command) from sc_retry;
select pg_temp.check('same request retry returns replay receipt','IDEMPOTENCY',(select (public.boss_games_mutate(request,command)->>'replayed')::boolean from sc_retry));
reset role;
select pg_temp.check('same request retry appends exactly one typed event','IDEMPOTENCY',(select count(*)=1 from public.game_soccer_events where game_id=pg_temp.sc_game('sc-authority') and request_id=pg_temp.f('duplicate-penalty')));
update pg_temp.phase5a_games set version=(select version from public.games where id=pg_temp.sc_game('sc-authority')) where label='sc-authority';
create temp table sc_scorer_assignment as select id from public.game_operator_assignments where game_id=pg_temp.sc_game('sc-authority') and person_id=pg_temp.f('scorer') and status='active';
grant select on sc_scorer_assignment to authenticated;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.game_op('game.operator.end','sc-authority',jsonb_build_object('assignment_id',(select id from sc_scorer_assignment)));
select pg_temp.actor('scorer');
select pg_temp.denied('ended exact assignment denies retained retry',format('select public.boss_games_mutate(%L,%L)',(select request from sc_retry),(select command from sc_retry)));
select pg_temp.check('ended exact assignment receives no private entry play context','PROJECTION',jsonb_array_length(pg_temp.sc_detail('sc-authority')->'entry_plays')=0);
reset role;
select pg_temp.check('denied replay preserves one original event','IDEMPOTENCY',(select count(*)=1 from public.game_soccer_events where game_id=pg_temp.sc_game('sc-authority') and request_id=pg_temp.f('duplicate-penalty')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('replay-families');
do $$declare op text;extra jsonb;command jsonb;request uuid;result jsonb;begin
 for op,extra in select * from(values
 ('soccer.clock.start','{}'::jsonb),('soccer.clock.stop','{}'::jsonb),('soccer.clock.set','{"clock_ms":30000,"reason":"Synthetic retained clock"}'::jsonb),('soccer.added_time.set','{"added_time_seconds":10,"reason":"Synthetic retained allowance"}'::jsonb),
 ('soccer.event.add','{"event_type":"shot_off_target","side":"primary"}'::jsonb),('soccer.event.add','{"event_type":"shot_blocked","side":"primary"}'::jsonb),('soccer.event.add','{"event_type":"penalty_miss","side":"primary"}'::jsonb)
 )v(op,extra)loop
  request:=pg_temp.f('sc-replay-'||op||extra::text);command:=pg_temp.game_command(op,'replay-families',extra);result:=public.boss_games_mutate(request,command);
  update pg_temp.phase5a_games set version=(result->>'version')::bigint where label='replay-families';
  perform pg_temp.check('retry receipt for '||op||extra::text,'IDEMPOTENCY',(public.boss_games_mutate(request,command)->>'replayed')::boolean);
  perform pg_temp.conflict('same request rejects changed payload '||op||extra::text,format('select public.boss_games_mutate(%L,%L)',request,command||'{"input":{"game_id":"00000000-0000-0000-0000-000000000001","expected_version":1}}'::jsonb));
 end loop;
end$$;
reset role;
select pg_temp.check('clock and shot replay families append one fact per original receipt','IDEMPOTENCY',(select count(*)=7 and count(distinct e.request_id)=7 from public.game_soccer_events e where e.game_id=pg_temp.sc_game('replay-families')and e.event_type in('clock_start','clock_stop','clock_set','added_time_set','shot_off_target','shot_blocked','penalty_miss')));
create temp table sc_auth_retry(request uuid,command jsonb);grant select,insert on sc_auth_retry to authenticated;
set local role authenticated;select pg_temp.actor('admin');
insert into sc_auth_retry values(pg_temp.f('sc-auth-original-clock'),pg_temp.game_command('soccer.clock.set','replay-families','{"clock_ms":40000,"reason":"Synthetic retained original request"}'));
select pg_temp.sc_op('soccer.clock.set','replay-families','{"clock_ms":40000,"reason":"Synthetic retained original request"}','sc-auth-original-clock');
reset role;update auth.sessions set not_after=clock_timestamp()-interval '1 second'where id=pg_temp.f('session-admin');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.denied('expired real fixture session denies retained sport retry',format('select public.boss_games_mutate(%L,%L)',(select request from sc_auth_retry),(select command from sc_auth_retry)),'PT401');
select pg_temp.denied('expired real fixture session denies Soccer read',format('select public.boss_games_read(%L)',pg_temp.query('replay-families')),'PT401');
select pg_temp.denied('expired real fixture session denies new sport command',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-expired-new-goal'),pg_temp.game_command('soccer.event.add','replay-families','{"event_type":"goal","side":"primary"}')),'PT401');
reset role;
select pg_temp.check('expired retry creates no duplicate accepted sport fact','IDEMPOTENCY',(select count(*)=1 from public.game_soccer_events where game_id=pg_temp.sc_game('replay-families')and request_id=pg_temp.f('sc-auth-original-clock')));
do $$declare t text;begin
 foreach t in array array['game_soccer_states','game_soccer_events','game_soccer_lineups','game_soccer_finalizations','game_soccer_final_stats'] loop
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
