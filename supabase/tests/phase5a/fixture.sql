-- Synthetic-only fixture, included inside each rollback-only Phase 5A suite.
-- No real identity, DOB, password, token or customer record is used.
create temp table phase5a_assertions(label text primary key,category text not null) on commit drop;
create temp table phase5a_games(label text primary key,id uuid not null,version bigint not null) on commit drop;
grant select,insert,update on phase5a_assertions,phase5a_games to authenticated,anon;
create function pg_temp.f(label text) returns uuid language sql immutable as $$select md5('boss-phase5a-test:'||label)::uuid$$;
create function pg_temp.check(label text,category text,ok boolean) returns void language plpgsql as $$begin
 if ok is distinct from true then raise exception 'FAIL Phase5A [%] %',category,label;end if;
 insert into pg_temp.phase5a_assertions values(label,category);
end$$;
create function pg_temp.actor(label text) returns void language plpgsql as $$begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.f('auth-'||label),'role','authenticated','is_anonymous',false,'session_id',pg_temp.f('session-'||label))::text,true);
end$$;
create function pg_temp.denied(label text,statement text,expected text default 'PT403') returns void language plpgsql as $$declare denied boolean:=false;begin
 begin execute statement;exception when others then
  if sqlstate=expected then denied:=true;else raise exception 'FAIL Phase5A % unexpected %: %',label,sqlstate,sqlerrm;end if;
 end;perform pg_temp.check(label,'DENIAL',denied);
end$$;
create function pg_temp.conflict(label text,statement text) returns void language plpgsql as $$declare denied boolean:=false;begin
 begin execute statement;exception when sqlstate 'PT409' or sqlstate 'PT422' then denied:=true;end;
 perform pg_temp.check(label,'CONFLICT',denied);
end$$;
create function pg_temp.state_denied(label text,statement text) returns void language plpgsql as $$declare denied boolean:=false;begin
 begin execute statement;exception when sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then denied:=true;end;
 perform pg_temp.check(label,'STATE_DENIAL',denied);
end$$;
create function pg_temp.key(n int default 0) returns text language sql stable as $$
 select to_char((date_trunc('day',now())+interval '20 days 18 hours'+n*interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS')
$$;
create function pg_temp.cmd(op text,input jsonb) returns jsonb language sql immutable as $$select jsonb_build_object('operation',op,'input',input)$$;
create function pg_temp.create_command(event_label text,primary_label text default 'falcons',sport text default 'basketball',n int default 0) returns jsonb language sql stable as $$
 select pg_temp.cmd('game.create',jsonb_build_object('organization_id',pg_temp.f(case when event_label='other' then 'other-org' else 'org' end),'event_id',pg_temp.f('event-'||event_label),'expected_event_version',1,'occurrence_key',pg_temp.key(n),'primary_team_id',pg_temp.f(primary_label),'sport_key',sport,'competition_type',case when event_label='neutral' then 'tournament' else 'standard' end))
$$;
create function pg_temp.create_game(label text,event_label text,primary_label text default 'falcons',sport text default 'basketball',n int default 0) returns jsonb language plpgsql as $$declare result jsonb;begin
 result:=public.boss_games_mutate(pg_temp.f('request-create-'||label),pg_temp.create_command(event_label,primary_label,sport,n));
 insert into pg_temp.phase5a_games values(label,(result->>'game_id')::uuid,(result->>'version')::bigint);
 return result;
end$$;
create function pg_temp.game_command(op text,label text,extra jsonb default '{}',version_override bigint default null) returns jsonb language sql stable as $$
 select pg_temp.cmd(op,jsonb_build_object('game_id',id,'expected_version',coalesce(version_override,version))||extra) from pg_temp.phase5a_games where phase5a_games.label=game_command.label
$$;
create function pg_temp.game_op(op text,label text,extra jsonb default '{}',request_label text default null) returns jsonb language plpgsql as $$declare result jsonb;begin
 result:=public.boss_games_mutate(pg_temp.f(coalesce(request_label,op||'-'||label||'-'||(select version from pg_temp.phase5a_games where phase5a_games.label=game_op.label))),pg_temp.game_command(op,label,extra));
 update pg_temp.phase5a_games set version=(result->>'version')::bigint where phase5a_games.label=game_op.label;
 return result;
end$$;
create function pg_temp.query(game_label text default null,extra jsonb default '{}') returns jsonb language sql stable as $$
 select jsonb_build_object('organization_id',pg_temp.f('org'),'view','all','from',to_char((now()-interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),'to',to_char((now()+interval '40 days') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))||extra||case when game_label is null then '{}'::jsonb else jsonb_build_object('game_id',(select id from pg_temp.phase5a_games where label=game_label)) end
$$;
revoke all on function pg_temp.f(text),pg_temp.check(text,text,boolean),pg_temp.actor(text),pg_temp.denied(text,text,text),pg_temp.conflict(text,text),pg_temp.state_denied(text,text),pg_temp.key(int),pg_temp.cmd(text,jsonb),pg_temp.create_command(text,text,text,int),pg_temp.create_game(text,text,text,text,int),pg_temp.game_command(text,text,jsonb,bigint),pg_temp.game_op(text,text,jsonb,text),pg_temp.query(text,jsonb) from public;
grant execute on function pg_temp.f(text),pg_temp.check(text,text,boolean),pg_temp.actor(text),pg_temp.denied(text,text,text),pg_temp.conflict(text,text),pg_temp.state_denied(text,text),pg_temp.key(int),pg_temp.cmd(text,jsonb),pg_temp.create_command(text,text,text,int),pg_temp.create_game(text,text,text,text,int),pg_temp.game_command(text,text,jsonb,bigint),pg_temp.game_op(text,text,jsonb,text),pg_temp.query(text,jsonb) to authenticated,anon;

insert into public.people(id,display_name) select pg_temp.f(label),'Synthetic Game Center '||label from unnest(array['admin','other-admin','director','program','coach','assistant','scorer','streamer','staff','parent','household-only','child1','child2','child3'])label;
insert into auth.users(id,email,email_confirmed_at) select pg_temp.f('auth-'||label),label||'@phase5a.example.invalid',now()-interval '3 days' from unnest(array['admin','other-admin','director','program','coach','assistant','scorer','streamer','staff','parent','household-only','child1','child2','child3'])label;
insert into auth.sessions(id,user_id) select pg_temp.f('session-'||label),pg_temp.f('auth-'||label) from unnest(array['admin','other-admin','director','program','coach','assistant','scorer','streamer','staff','parent','household-only','child1','child2','child3'])label;
insert into public.user_accounts(person_id,auth_user_id,account_status) select pg_temp.f(label),pg_temp.f('auth-'||label),'active' from unnest(array['admin','other-admin','director','program','coach','assistant','scorer','streamer','staff','parent','household-only','child1','child2','child3'])label;
insert into public.organizations(id,name,slug) values(pg_temp.f('org'),'Synthetic Game Center tenant','synthetic-phase5a-games'),(pg_temp.f('other-org'),'Synthetic other Game Center tenant','synthetic-phase5a-other');
insert into public.organization_units(id,organization_id,unit_type,name,slug) values(pg_temp.f('unit'),pg_temp.f('org'),'program','Synthetic program','games-program'),(pg_temp.f('sibling-unit'),pg_temp.f('org'),'program','Synthetic sibling program','games-sibling');
insert into public.seasons(id,organization_id,parent_unit_id,name,status) values(pg_temp.f('season'),pg_temp.f('org'),pg_temp.f('unit'),'Synthetic season','active');
insert into public.teams(id,organization_id,parent_unit_id,season_id,name,slug,status,visibility) values
 (pg_temp.f('falcons'),pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic Falcons','games-falcons','active','member'),
 (pg_temp.f('wildcats'),pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic Wildcats','games-wildcats','active','member'),
 (pg_temp.f('tigers'),pg_temp.f('org'),pg_temp.f('sibling-unit'),null,'Synthetic Tigers','games-tigers','active','member'),
 (pg_temp.f('other-team'),pg_temp.f('other-org'),null,null,'Synthetic Other','games-other','active','member');
insert into public.organization_memberships(organization_id,person_id,starts_at,created_at) select pg_temp.f(case when label='other-admin' then 'other-org' else 'org' end),pg_temp.f(label),now()-interval '3 days',now()-interval '3 days' from unnest(array['admin','other-admin','director','program','coach','assistant','scorer','streamer','staff','parent','child1','child2','child3'])label;
insert into public.participants(id,person_id) select pg_temp.f('participant-'||label),pg_temp.f(label) from unnest(array['child1','child2','child3'])label;
insert into public.team_memberships(id,organization_id,team_id,person_id,participant_id,membership_type,jersey_number,position_label,starts_at,created_at)
 select pg_temp.f('membership-'||label),pg_temp.f('org'),pg_temp.f(case when label='child2' then 'wildcats' when label='child3' then 'tigers' else 'falcons' end),pg_temp.f(label),pg_temp.f('participant-'||label),'athlete',case when label='child1' then '12' else '4' end,'Synthetic position',now()-interval '3 days',now()-interval '3 days' from unnest(array['child1','child2','child3'])label;
insert into public.team_memberships(id,organization_id,team_id,person_id,membership_type,starts_at,created_at)
 select pg_temp.f('membership-'||label),pg_temp.f('org'),pg_temp.f('falcons'),pg_temp.f(label),case when label='coach' then 'head_coach' when label='assistant' then 'assistant_coach' else 'staff' end,now()-interval '3 days',now()-interval '3 days' from unnest(array['coach','assistant','scorer','streamer','staff'])label;
insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,created_at) values(pg_temp.f('guardian-child1'),pg_temp.f('parent'),pg_temp.f('child1'),'active',now()-interval '3 days',now()-interval '3 days',now()-interval '3 days');
insert into public.households(id,name) values(pg_temp.f('household'),'Synthetic Game Center household');
insert into public.household_memberships(household_id,person_id,relationship_type,starts_at,created_at) select pg_temp.f('household'),pg_temp.f(label),'member',now()-interval '3 days',now()-interval '3 days' from unnest(array['household-only','parent','child1'])label;
insert into public.role_assignments(id,person_id,role_id,scope_type,scope_id,organization_id,starts_at,created_at)
 select pg_temp.f('role-'||label),pg_temp.f(label),role.id,case when label in ('coach','assistant','scorer','streamer','staff') then 'team' when label='program' then 'organization_unit' else 'organization' end,pg_temp.f(case when label in ('coach','assistant','scorer','streamer','staff') then 'falcons' when label='program' then 'unit' when label='other-admin' then 'other-org' else 'org' end),pg_temp.f(case when label='other-admin' then 'other-org' else 'org' end),now()-interval '3 days',now()-interval '3 days'
 from unnest(array['admin','other-admin','director','program','coach','assistant','scorer','streamer','staff'])label join public.roles role on role.key=case label when 'coach' then 'head_coach' when 'assistant' then 'assistant_coach' when 'scorer' then 'scorekeeper' when 'streamer' then 'livestream_operator' when 'staff' then 'team_staff' when 'program' then 'program_administrator' when 'director' then 'athletic_director' else 'organization_administrator' end;
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at) select pg_temp.f(label),m.id,'active',case when m.key='sports' then '{"game_center":true,"game_operations":true,"team_game_management":true,"head_coach_game_management":true}'::jsonb else '{"conflicts":false,"head_coach_management":true}'::jsonb end,now()-interval '3 days' from unnest(array['org','other-org'])label cross join public.modules m where m.key in('sports','calendar');
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,recurrence,created_by_person_id,updated_by_person_id)
 select pg_temp.f('event-'||label),pg_temp.f(case when label='other' then 'other-org' else 'org' end),'Synthetic Game Center '||label,case when label='practice' then 'practice' else 'game' end,date_trunc('day',now())+interval '20 days 18 hours',date_trunc('day',now())+interval '20 days 20 hours','UTC','scheduled','member','optional',case when label='recurring' then '{"frequency":"daily","interval":1,"count":3}'::jsonb else null end,pg_temp.f(case when label='other' then 'other-admin' else 'admin' end),pg_temp.f(case when label='other' then 'other-admin' else 'admin' end)
 from unnest(array['internal','external','neutral','wildcats','sibling','other','recurring','calendar','history','denial','practice','race-start','race-score','race-final','race-reopen','race-operator','race-schedule','race-authority'])label;
insert into public.event_targets(event_id,organization_id,target_type,target_id)
 select pg_temp.f('event-'||label),pg_temp.f(case when label='other' then 'other-org' else 'org' end),'team',pg_temp.f(case when label='wildcats' then 'wildcats' when label='sibling' then 'tigers' when label='other' then 'other-team' else 'falcons' end)
 from unnest(array['internal','external','neutral','wildcats','sibling','other','recurring','calendar','history','denial','practice','race-start','race-score','race-final','race-reopen','race-operator','race-schedule','race-authority'])label;
insert into public.event_targets(event_id,organization_id,target_type,target_id) select pg_temp.f('event-'||label),pg_temp.f('org'),'team',pg_temp.f('wildcats') from unnest(array['internal','neutral'])label;
insert into public.event_game_details(event_id,organization_id,opponent_team_id,external_opponent_name,home_away)
 select pg_temp.f('event-'||label),pg_temp.f(case when label='other' then 'other-org' else 'org' end),case when label in('internal','neutral') then pg_temp.f('wildcats') else null end,case when label in('internal','neutral') then null else 'Synthetic External Opponent' end,case when label='neutral' then 'neutral' else 'home' end
 from unnest(array['internal','external','neutral','wildcats','sibling','other','recurring','calendar','history','denial','race-start','race-score','race-final','race-reopen','race-operator','race-schedule','race-authority'])label;
