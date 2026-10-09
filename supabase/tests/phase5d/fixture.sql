-- Disposable synthetic Football fixture. Never run against hosted infrastructure.
-- Reuse the canonical Game Center fixture exactly once, with six additional
-- athletes per side: 1 QB, 2 runner, 3 receiver, 4 returner, 5/6 defense, 7 kicker.
\ir ../phase5a/fixture.sql
create function pg_temp.ff_id(label text) returns uuid language sql immutable as $$select md5('boss-phase5d-test:'||label)::uuid$$;
revoke all on function pg_temp.ff_id(text) from public;
grant execute on function pg_temp.ff_id(text) to authenticated,anon;
insert into public.people(id,display_name)
 select pg_temp.ff_id(side||'-player-'||n),'Synthetic Football '||side||' player '||n
 from unnest(array['primary','opponent'])side cross join generate_series(2,7)n;
insert into public.participants(id,person_id)
 select pg_temp.ff_id(side||'-participant-'||n),pg_temp.ff_id(side||'-player-'||n)
 from unnest(array['primary','opponent'])side cross join generate_series(2,7)n;
insert into public.organization_memberships(organization_id,person_id,starts_at,created_at)
 select pg_temp.f('org'),pg_temp.ff_id(side||'-player-'||n),now()-interval '3 days',now()-interval '3 days'
 from unnest(array['primary','opponent'])side cross join generate_series(2,7)n;
insert into public.team_memberships(id,organization_id,team_id,person_id,participant_id,membership_type,jersey_number,position_label,starts_at,created_at)
 select pg_temp.ff_id(side||'-membership-'||n),pg_temp.f('org'),pg_temp.f(case side when 'primary' then 'falcons' else 'wildcats' end),
 pg_temp.ff_id(side||'-player-'||n),pg_temp.ff_id(side||'-participant-'||n),'athlete',(60+n)::text,'Synthetic Football position',now()-interval '3 days',now()-interval '3 days'
 from unnest(array['primary','opponent'])side cross join generate_series(2,7)n;
update public.organization_modules set configuration=configuration||'{"football_live_scoring":true,"football_stats":true,"football_play_by_play":true,"football_lineups":true}'
 where organization_id in(pg_temp.f('org'),pg_temp.f('other-org')) and module_id=(select id from public.modules where key='sports');
create function pg_temp.ff_game(label text) returns uuid language sql stable as $$select id from pg_temp.phase5a_games where phase5a_games.label=ff_game.label$$;
create function pg_temp.ff_roster(label text,side text,n integer) returns uuid language sql stable security definer set search_path='' as $$
 select s.id from public.game_roster_snapshots s join public.games g on g.id=s.game_id
 where g.id=pg_temp.ff_game(label) and s.revision=g.roster_revision and s.person_id=
 case when n=1 then pg_temp.f(case side when 'primary' then 'child1' else 'child2' end) else pg_temp.ff_id(side||'-player-'||n) end
$$;
create function pg_temp.ff_op(operation text,label text,extras jsonb default '{}',request_label text default null) returns jsonb language plpgsql as $$begin
 return pg_temp.game_op(operation,label,extras,coalesce(request_label,'ff-'||operation||'-'||label||'-'||(select version from pg_temp.phase5a_games where phase5a_games.label=ff_op.label)));
end$$;
create function pg_temp.ff_clone_event(label text,template_label text default 'internal') returns text language plpgsql security definer set search_path='' as $$declare event_label text:='ff-'||label;begin
 insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,created_by_person_id,updated_by_person_id)
 select pg_temp.f('event-'||event_label),organization_id,'Synthetic Football '||label,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,created_by_person_id,updated_by_person_id from public.events where id=pg_temp.f('event-'||template_label);
 insert into public.event_targets(event_id,organization_id,target_type,target_id)
 select pg_temp.f('event-'||event_label),organization_id,target_type,target_id from public.event_targets where event_id=pg_temp.f('event-'||template_label);
 insert into public.event_game_details(event_id,organization_id,opponent_team_id,external_opponent_name,home_away)
 select pg_temp.f('event-'||event_label),organization_id,opponent_team_id,external_opponent_name,home_away from public.event_game_details where event_id=pg_temp.f('event-'||template_label);
 return event_label;
end$$;
create function pg_temp.ff_link(label text,event_label text default 'internal',primary_label text default 'falcons',sport text default 'football') returns void language plpgsql as $$begin
 perform pg_temp.create_game(label,pg_temp.ff_clone_event(label,event_label),primary_label,sport);
 perform pg_temp.game_op('game.roster.snapshot',label);
 perform pg_temp.game_op('game.operator.assign',label,jsonb_build_object('person_id',pg_temp.f('admin'),'role_assignment_id',pg_temp.f('role-admin'),'function_key','game_administrator','team_id',pg_temp.f(primary_label),'ends_at',clock_timestamp()+interval '1 hour'));
end$$;
create function pg_temp.ff_detail(label text,extras jsonb default '{}') returns jsonb language sql stable as $$
 select g->'football' from jsonb_array_elements(public.boss_games_read(pg_temp.query(label,extras))->'games')g
$$;
create function pg_temp.ff_lineup(label text,side text,count_players int default 7) returns jsonb language sql stable as $$
 select jsonb_build_object('side',side,'roster_ids',jsonb_agg(pg_temp.ff_roster(label,side,n)order by n)) from generate_series(1,count_players)n
$$;
create function pg_temp.ff_create(label text,event_label text default 'internal',start_game boolean default true,enforce boolean default false,lineup_count int default 7,extra_config jsonb default '{}') returns void language plpgsql as $$begin
 perform pg_temp.ff_link(label,event_label);
 perform pg_temp.ff_op('football.configure',label,jsonb_build_object('quarter_seconds',360,'overtime_format','none','overtime_seconds',60,'max_overtime_periods',0,'play_clock_seconds',25,'lineup_size',lineup_count,'enforce_lineup',enforce,'kneel_counts_as_rush',true)||extra_config);
 if enforce then
  perform pg_temp.ff_op('football.lineup.set',label,pg_temp.ff_lineup(label,'primary',lineup_count));
  if pg_temp.ff_roster(label,'opponent',1)is not null then perform pg_temp.ff_op('football.lineup.set',label,pg_temp.ff_lineup(label,'opponent',lineup_count));end if;
 end if;
 if start_game then
  perform pg_temp.game_op('game.start',label);perform pg_temp.ff_op('football.period.start',label);
  perform pg_temp.ff_op('football.state.set',label,'{"side":"primary","ball_spot":30,"down":1,"distance":10,"primary_direction":"increasing","reason":"Synthetic confirmed opening placement"}');
 end if;
end$$;
create function pg_temp.ff_event_id(label text,request_label text) returns uuid language sql stable security definer set search_path='' as $$
 select id from public.game_football_events where game_id=pg_temp.ff_game(label)and request_id=pg_temp.f(request_label)order by sequence desc limit 1
$$;
create function pg_temp.ff_play(label text,play_type text,side text default 'primary',extras jsonb default '{}',request_label text default null) returns uuid language plpgsql as $$declare request text;begin
 request:=coalesce(request_label,'ff-play-'||label||'-'||(select version from pg_temp.phase5a_games where phase5a_games.label=ff_play.label));
 perform pg_temp.ff_op('football.play.add',label,jsonb_build_object('play_type',play_type,'side',side)||extras,request);
 return pg_temp.ff_event_id(label,request);
end$$;
create function pg_temp.ff_clock(label text,ms bigint) returns void language plpgsql as $$begin
 perform pg_temp.ff_op('football.clock.set',label,jsonb_build_object('clock_ms',ms,'reason','Synthetic confirmed remaining clock'));
end$$;
create function pg_temp.ff_end(label text) returns void language plpgsql as $$begin
 perform pg_temp.ff_clock(label,0);perform pg_temp.ff_op('football.period.end',label);
end$$;
create function pg_temp.ff_finish(label text) returns void language plpgsql as $$declare period int;state text;begin
 select (d->>'period_number')::int,d->>'period_status' into period,state from pg_temp.ff_detail(label)d;
 while period<4 loop
  if state='active'then perform pg_temp.ff_end(label);end if;
  perform pg_temp.ff_op('football.period.start',label);period:=period+1;state:='active';
 end loop;
 if state='active'then perform pg_temp.ff_end(label);end if;
end$$;
create function pg_temp.ff_stats(label text,side text,n int default 0) returns jsonb language sql volatile security definer set search_path='' as $$
 select t.stats from boss_private.football_totals(pg_temp.ff_game(label))t where t.side=ff_stats.side and t.roster_id is not distinct from case when n=0 then null::uuid else pg_temp.ff_roster(label,side,n)end
$$;
create function pg_temp.ff_box(label text) returns jsonb language sql volatile security definer set search_path='' as $$
 select jsonb_agg(to_jsonb(t))from boss_private.football_totals(pg_temp.ff_game(label))t
$$;
create function pg_temp.ff_drives(label text) returns jsonb language sql volatile security definer set search_path='' as $$
 select boss_private.football_drives(pg_temp.ff_game(label))
$$;
create function pg_temp.ff_expect(label text,side text,n int,expected jsonb,assertion_label text) returns void language plpgsql as $$declare actual jsonb;kv record;begin
 actual:=pg_temp.ff_stats(label,side,n);
 perform pg_temp.check(assertion_label||' row exists','ORACLE',actual is not null);
 for kv in select * from jsonb_each(expected)loop
  perform pg_temp.check(assertion_label||'/'||kv.key,'ORACLE',actual->kv.key is not distinct from kv.value);
 end loop;
end$$;
revoke all on function pg_temp.ff_game(text),pg_temp.ff_roster(text,text,int),pg_temp.ff_op(text,text,jsonb,text),pg_temp.ff_clone_event(text,text),pg_temp.ff_link(text,text,text,text),pg_temp.ff_detail(text,jsonb),pg_temp.ff_lineup(text,text,int),pg_temp.ff_create(text,text,boolean,boolean,int,jsonb),pg_temp.ff_event_id(text,text),pg_temp.ff_play(text,text,text,jsonb,text),pg_temp.ff_clock(text,bigint),pg_temp.ff_end(text),pg_temp.ff_finish(text),pg_temp.ff_stats(text,text,int),pg_temp.ff_box(text),pg_temp.ff_drives(text),pg_temp.ff_expect(text,text,int,jsonb,text) from public;
grant execute on function pg_temp.ff_game(text),pg_temp.ff_roster(text,text,int),pg_temp.ff_op(text,text,jsonb,text),pg_temp.ff_clone_event(text,text),pg_temp.ff_link(text,text,text,text),pg_temp.ff_detail(text,jsonb),pg_temp.ff_lineup(text,text,int),pg_temp.ff_create(text,text,boolean,boolean,int,jsonb),pg_temp.ff_event_id(text,text),pg_temp.ff_play(text,text,text,jsonb,text),pg_temp.ff_clock(text,bigint),pg_temp.ff_end(text),pg_temp.ff_finish(text),pg_temp.ff_stats(text,text,int),pg_temp.ff_box(text),pg_temp.ff_drives(text),pg_temp.ff_expect(text,text,int,jsonb,text) to authenticated,anon;
