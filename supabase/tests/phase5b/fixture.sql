-- Phase 5B extends the unchanged synthetic Phase 5A fixture. Never hosted.
\ir ../phase5a/fixture.sql
create function pg_temp.bb_id(label text) returns uuid language sql immutable as $$select md5('boss-phase5b-test:'||label)::uuid$$;
revoke all on function pg_temp.bb_id(text) from public;
grant execute on function pg_temp.bb_id(text) to authenticated,anon;
insert into public.people(id,display_name)
 select pg_temp.bb_id(side||'-player-'||n),'Synthetic Basketball '||side||' player '||n
 from unnest(array['primary','opponent'])side cross join generate_series(2,6)n;
insert into public.participants(id,person_id)
 select pg_temp.bb_id(side||'-participant-'||n),pg_temp.bb_id(side||'-player-'||n)
 from unnest(array['primary','opponent'])side cross join generate_series(2,6)n;
insert into public.organization_memberships(organization_id,person_id,starts_at,created_at)
 select pg_temp.f('org'),pg_temp.bb_id(side||'-player-'||n),now()-interval '3 days',now()-interval '3 days'
 from unnest(array['primary','opponent'])side cross join generate_series(2,6)n;
insert into public.team_memberships(id,organization_id,team_id,person_id,participant_id,membership_type,jersey_number,position_label,starts_at,created_at)
 select pg_temp.bb_id(side||'-membership-'||n),pg_temp.f('org'),pg_temp.f(case side when 'primary' then 'falcons' else 'wildcats' end),
 pg_temp.bb_id(side||'-player-'||n),pg_temp.bb_id(side||'-participant-'||n),'athlete',(20+n)::text,'Synthetic basketball position',now()-interval '3 days',now()-interval '3 days'
 from unnest(array['primary','opponent'])side cross join generate_series(2,6)n;
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":true,"basketball_stats":true,"basketball_play_by_play":true,"basketball_lineups":true}'
 where organization_id in(pg_temp.f('org'),pg_temp.f('other-org')) and module_id=(select id from public.modules where key='sports');
create function pg_temp.bb_game(label text) returns uuid language sql stable as $$select id from pg_temp.phase5a_games where phase5a_games.label=bb_game.label$$;
create function pg_temp.bb_roster(label text,side text,n integer) returns uuid language sql stable security definer set search_path='' as $$
 select s.id from public.game_roster_snapshots s join public.games g on g.id=s.game_id
 where g.id=pg_temp.bb_game(label) and s.revision=g.roster_revision and s.person_id=
 case when n=1 then pg_temp.f(case side when 'primary' then 'child1' else 'child2' end) else pg_temp.bb_id(side||'-player-'||n) end
$$;
create function pg_temp.bb_op(op text,label text,extra jsonb default '{}',request_label text default null) returns jsonb language plpgsql as $$begin
 return pg_temp.game_op(op,label,extra,coalesce(request_label,'bb-'||op||'-'||label||'-'||(select version from pg_temp.phase5a_games where phase5a_games.label=bb_op.label)));
end$$;
create function pg_temp.bb_lineup(label text,side text) returns jsonb language sql stable as $$
 select jsonb_build_object('side',side,'roster_ids',jsonb_agg(pg_temp.bb_roster(label,side,n) order by n)) from generate_series(1,5)n
$$;
create function pg_temp.bb_create(label text,event_label text default 'internal',start_game boolean default true,periods int default 2,enforce boolean default true) returns void language plpgsql as $$begin
 perform pg_temp.create_game(label,event_label);
 perform pg_temp.game_op('game.roster.snapshot',label);
 perform pg_temp.game_op('game.operator.assign',label,jsonb_build_object('person_id',pg_temp.f('admin'),'role_assignment_id',pg_temp.f('role-admin'),'function_key','game_administrator','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
 perform pg_temp.bb_op('basketball.configure',label,jsonb_build_object('regulation_periods',periods,'period_seconds',60,'overtime_seconds',60,'lineup_size',5,'enforce_lineup',enforce));
 if enforce then
  perform pg_temp.bb_op('basketball.lineup.set',label,pg_temp.bb_lineup(label,'primary'));
  if pg_temp.bb_roster(label,'opponent',1) is not null then perform pg_temp.bb_op('basketball.lineup.set',label,pg_temp.bb_lineup(label,'opponent'));end if;
 end if;
 if start_game then perform pg_temp.game_op('game.start',label);perform pg_temp.bb_op('basketball.period.start',label);end if;
end$$;
create function pg_temp.bb_event_id(label text,request text) returns uuid language sql stable security definer set search_path='' as $$
 select id from public.game_basketball_events where game_id=pg_temp.bb_game(label) and request_id=pg_temp.f(request) order by sequence desc limit 1
$$;
create function pg_temp.bb_event(label text,kind text,side text default 'primary',n int default 1,request_label text default null,score_event uuid default null) returns uuid language plpgsql as $$declare request text;begin
 request:=coalesce(request_label,'bb-event-'||label||'-'||(select version from pg_temp.phase5a_games where phase5a_games.label=bb_event.label));
 perform pg_temp.bb_op('basketball.event.add',label,jsonb_build_object('event_type',kind,'side',side)||
 case when n=0 then '{}'::jsonb else jsonb_build_object('roster_id',pg_temp.bb_roster(label,side,n)) end||
 case when score_event is null then '{}'::jsonb else jsonb_build_object('scoring_event_id',score_event) end,request);
 return pg_temp.bb_event_id(label,request);
end$$;
create function pg_temp.bb_detail(label text,extra jsonb default '{}') returns jsonb language sql stable as $$
 select g->'basketball' from jsonb_array_elements(public.boss_games_read(pg_temp.query(label,extra))->'games')g
$$;
create function pg_temp.bb_end(label text) returns void language plpgsql as $$begin
 perform pg_temp.bb_op('basketball.clock.set',label,'{"clock_ms":0,"reason":"Synthetic period completion"}');
 perform pg_temp.bb_op('basketball.period.end',label);
end$$;
create function pg_temp.bb_finish(label text) returns void language plpgsql as $$declare current_period int;regulation int;begin
 select (pg_temp.bb_detail(label)->>'period_number')::int,(pg_temp.bb_detail(label)->>'regulation_periods')::int into current_period,regulation;
 while current_period<regulation loop
  perform pg_temp.bb_end(label);perform pg_temp.bb_op('basketball.period.start',label);current_period:=current_period+1;
 end loop;
 perform pg_temp.bb_end(label);
end$$;
create function pg_temp.bb_box(label text) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_agg(to_jsonb(t)) from boss_private.basketball_totals(pg_temp.bb_game(label))t
$$;
revoke all on function pg_temp.bb_game(text),pg_temp.bb_roster(text,text,int),pg_temp.bb_op(text,text,jsonb,text),pg_temp.bb_lineup(text,text),pg_temp.bb_create(text,text,boolean,int,boolean),pg_temp.bb_event_id(text,text),pg_temp.bb_event(text,text,text,int,text,uuid),pg_temp.bb_detail(text,jsonb),pg_temp.bb_end(text),pg_temp.bb_finish(text) from public;
grant execute on function pg_temp.bb_game(text),pg_temp.bb_roster(text,text,int),pg_temp.bb_op(text,text,jsonb,text),pg_temp.bb_lineup(text,text),pg_temp.bb_create(text,text,boolean,int,boolean),pg_temp.bb_event_id(text,text),pg_temp.bb_event(text,text,text,int,text,uuid),pg_temp.bb_detail(text,jsonb),pg_temp.bb_end(text),pg_temp.bb_finish(text) to authenticated,anon;
revoke all on function pg_temp.bb_box(text) from public;
grant execute on function pg_temp.bb_box(text) to authenticated,anon;
