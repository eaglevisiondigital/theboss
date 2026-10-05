-- Reproduce the hosted Calendar -> Game Center mismatch without live writes.
-- All identities, windows and resources are disposable synthetic fixtures.
begin;
\ir phase5a/fixture.sql

-- Match the original platform-administrator baseline and finite feature state.
update public.role_assignments set status='inactive' where id=pg_temp.f('role-admin');
insert into public.role_assignments(id,person_id,role_id,scope_type,scope_id,starts_at,created_at)
 select pg_temp.f('platform-admin-role'),pg_temp.f('admin'),id,'platform',null,now()-interval '3 days',now()-interval '3 days'
 from public.roles where key='platform_administrator';
update public.organization_modules set configuration='{"game_center":true,"game_operations":true,"football_live_scoring":true,"football_stats":true,"football_play_by_play":true}'
 where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
create temp table creation_context(event_id uuid,command jsonb) on commit drop;
grant select,insert,update on creation_context to authenticated;
set local role authenticated;
select pg_temp.actor('admin');
insert into creation_context(event_id)
select (public.boss_calendar_mutate(
 jsonb_build_object('operation','event.create','input',jsonb_build_object(
 'organization_id',pg_temp.f('org'),'title','Synthetic Football creation investigation',
 'event_type_key','game','start_at',date_trunc('minute',now())-interval '2 minutes',
 'end_at',date_trunc('minute',now())+interval '58 minutes','timezone','UTC',
 'status','scheduled','visibility','member','publication_state','unpublished',
 'rsvp_mode','not_required','recurrence',null,'reminders','[]'::jsonb,
 'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('falcons'))),
 'game',jsonb_build_object('opponent_team_id',pg_temp.f('wildcats'),'external_opponent_name',null,'home_away','home','game_status','scheduled'))),pg_temp.f('calendar-create-football-regression'))->>'resource_id')::uuid;
update creation_context set command=jsonb_build_object('operation','game.create','input',jsonb_build_object(
 'event_id',event_id,'expected_event_version',1,
 'occurrence_key',to_char((date_trunc('minute',now())-interval '2 minutes') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS'),
 'primary_team_id',pg_temp.f('falcons'),'sport_key','football','competition_type','standard'));
select pg_temp.check('native Calendar accepts one target with an internal opponent','CREATION',
 exists(select 1 from creation_context c join public.events e on e.id=c.event_id where e.version=1 and e.status='scheduled'));
do $$declare c jsonb;rejected boolean:=false;begin
 select command into c from creation_context;
 begin perform public.boss_games_mutate(pg_temp.f('hosted-shaped-create'),c);
 exception when sqlstate 'PT422' then rejected:=sqlerrm='Invalid game context';end;
 perform pg_temp.check('hosted-shaped create reproduces exact PT422 error','CREATION',rejected);
end$$;
select pg_temp.denied('same immutable request is again rejected',
 format('select public.boss_games_mutate(%L,%L)',pg_temp.f('hosted-shaped-create'),(select command from creation_context)),'PT422');

-- This fails before the fix: the read path offered a command the write path rejects.
select pg_temp.check('untargeted internal opponent is not offered as a create candidate','CANDIDATE',
 not exists(select 1 from creation_context c cross join lateral jsonb_array_elements(public.boss_games_read(pg_temp.query())->'create_candidates') x
 where x->>'event_id'=c.event_id::text));
reset role;
select pg_temp.check('failed create and retry leave no receipt or canonical game','ATOMICITY',
 not exists(select 1 from boss_private.game_operation_receipts where request_id=pg_temp.f('hosted-shaped-create'))
 and not exists(select 1 from public.games where event_id=(select event_id from creation_context)));

-- Explicitly targeting the opponent is the existing architecture, not a bypass.
insert into public.event_targets(event_id,organization_id,target_type,target_id)
 select event_id,pg_temp.f('org'),'team',pg_temp.f('wildcats') from creation_context;
-- Canonical game creation must also work before any sport-engine feature is on.
update public.organization_modules set configuration='{"game_center":true}'
 where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
set local role authenticated;
select pg_temp.check('both-target matchup is offered with original version and occurrence','CANDIDATE',
 exists(select 1 from creation_context c cross join lateral jsonb_array_elements(public.boss_games_read(pg_temp.query())->'create_candidates') x
 where x->>'event_id'=c.event_id::text and x->>'event_version'='1'
 and x->>'occurrence_key'=c.command->'input'->>'occurrence_key'));
do $$declare c jsonb;result jsonb;retry jsonb;begin
 select command into c from creation_context;
 result:=public.boss_games_mutate(pg_temp.f('valid-football-create'),c);
 retry:=public.boss_games_mutate(pg_temp.f('valid-football-create'),c);
 perform pg_temp.check('Football creates before engine configuration','CREATION',result->>'game_id' is not null and result->>'version'='1');
 perform pg_temp.check('valid Football retry preserves canonical identity','IDEMPOTENCY',retry->>'game_id'=result->>'game_id' and (retry->>'replayed')::boolean);
end$$;
select pg_temp.check('linked occurrence is removed from candidates','CANDIDATE',
 not exists(select 1 from creation_context c cross join lateral jsonb_array_elements(public.boss_games_read(pg_temp.query())->'create_candidates') x where x->>'event_id'=c.event_id::text));
reset role;
select pg_temp.check('game creation does not instantiate Football state or seals','ENGINE',
 exists(select 1 from public.games where event_id=(select event_id from creation_context) and sport_key='football' and competition_type='standard' and home_away='home')
 and not exists(select 1 from public.game_football_states) and not exists(select 1 from public.game_football_finalizations));

-- The common candidate fix preserves both other sports and external opponents.
set local role authenticated;
select pg_temp.check('single-target external opponent remains a candidate','CANDIDATE',
 exists(select 1 from jsonb_array_elements(public.boss_games_read(pg_temp.query())->'create_candidates') x where x->>'event_id'=pg_temp.f('event-external')::text));
select pg_temp.create_game('basketball-valid','internal','falcons','basketball');
select pg_temp.create_game('soccer-valid','neutral','falcons','soccer');
reset role;
select pg_temp.check('Basketball and Soccer still share the valid creation path','COMPATIBILITY',
 (select count(*) from public.games where sport_key in('basketball','soccer'))=2);
select category,count(*) passed_assertions from phase5a_assertions group by category order by category;
select count(*) passed_assertions from phase5a_assertions;
rollback;
