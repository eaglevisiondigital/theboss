-- Disposable synthetic Soccer fixture. Never run against hosted infrastructure.
-- The canonical Game Center fixture is reused, without Basketball state copies.
\ir ../phase5a/fixture.sql
create function pg_temp.sc_id(label text) returns uuid language sql immutable as $$select md5('boss-phase5c-test:'||label)::uuid$$;
revoke all on function pg_temp.sc_id(text) from public;
grant execute on function pg_temp.sc_id(text) to authenticated,anon;
insert into public.people(id,display_name)
 select pg_temp.sc_id(side||'-player-'||n),'Synthetic Soccer '||side||' player '||n
 from unnest(array['primary','opponent'])side cross join generate_series(2,12)n;
insert into public.participants(id,person_id)
 select pg_temp.sc_id(side||'-participant-'||n),pg_temp.sc_id(side||'-player-'||n)
 from unnest(array['primary','opponent'])side cross join generate_series(2,12)n;
insert into public.organization_memberships(organization_id,person_id,starts_at,created_at)
 select pg_temp.f('org'),pg_temp.sc_id(side||'-player-'||n),now()-interval '3 days',now()-interval '3 days'
 from unnest(array['primary','opponent'])side cross join generate_series(2,12)n;
insert into public.team_memberships(id,organization_id,team_id,person_id,participant_id,membership_type,jersey_number,position_label,starts_at,created_at)
 select pg_temp.sc_id(side||'-membership-'||n),pg_temp.f('org'),pg_temp.f(case side when 'primary' then 'falcons' else 'wildcats' end),
 pg_temp.sc_id(side||'-player-'||n),pg_temp.sc_id(side||'-participant-'||n),'athlete',(30+n)::text,'Synthetic Soccer position',now()-interval '3 days',now()-interval '3 days'
 from unnest(array['primary','opponent'])side cross join generate_series(2,12)n;
update public.organization_modules set configuration=configuration||'{"soccer_live_scoring":true,"soccer_stats":true,"soccer_play_by_play":true,"soccer_lineups":true}'
 where organization_id in(pg_temp.f('org'),pg_temp.f('other-org')) and module_id=(select id from public.modules where key='sports');
create function pg_temp.sc_game(label text) returns uuid language sql stable as $$select id from pg_temp.phase5a_games where phase5a_games.label=sc_game.label$$;
create function pg_temp.sc_roster(label text,side text,n integer) returns uuid language sql stable security definer set search_path='' as $$
 select s.id from public.game_roster_snapshots s join public.games g on g.id=s.game_id
 where g.id=pg_temp.sc_game(label) and s.revision=g.roster_revision and s.person_id=
 case when n=1 then pg_temp.f(case side when 'primary' then 'child1' else 'child2' end) else pg_temp.sc_id(side||'-player-'||n) end
$$;
create function pg_temp.sc_op(op text,label text,extra jsonb default '{}',request_label text default null) returns jsonb language plpgsql as $$begin
 return pg_temp.game_op(op,label,extra,coalesce(request_label,'sc-'||op||'-'||label||'-'||(select version from pg_temp.phase5a_games where phase5a_games.label=sc_op.label)));
end$$;
create function pg_temp.sc_roster_array(label text,side text,count_players int default 11) returns jsonb language sql stable as $$
 select coalesce(jsonb_agg(pg_temp.sc_roster(label,side,n) order by n),'[]') from generate_series(1,count_players)n
$$;
create function pg_temp.sc_clone_event(label text,template_label text default 'internal') returns text language plpgsql security definer set search_path='' as $$declare event_label text:='sc-'||label;begin
 insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,created_by_person_id,updated_by_person_id)
 select pg_temp.f('event-'||event_label),organization_id,'Synthetic Soccer '||label,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,created_by_person_id,updated_by_person_id
 from public.events where id=pg_temp.f('event-'||template_label);
 insert into public.event_targets(event_id,organization_id,target_type,target_id)
 select pg_temp.f('event-'||event_label),organization_id,target_type,target_id from public.event_targets where event_id=pg_temp.f('event-'||template_label);
 insert into public.event_game_details(event_id,organization_id,opponent_team_id,external_opponent_name,home_away)
 select pg_temp.f('event-'||event_label),organization_id,opponent_team_id,external_opponent_name,home_away from public.event_game_details where event_id=pg_temp.f('event-'||template_label);
 return event_label;
end$$;
create function pg_temp.sc_link(label text,event_label text default 'internal',primary_label text default 'falcons',sport text default 'soccer') returns void language plpgsql as $$begin
 perform pg_temp.create_game(label,pg_temp.sc_clone_event(label,event_label),primary_label,sport);
 perform pg_temp.game_op('game.roster.snapshot',label);
 perform pg_temp.game_op('game.operator.assign',label,jsonb_build_object('person_id',pg_temp.f('admin'),'role_assignment_id',pg_temp.f('role-admin'),'function_key','game_administrator','team_id',pg_temp.f(primary_label),'ends_at',clock_timestamp()+interval '1 hour'));
end$$;
create function pg_temp.sc_detail(label text,extra jsonb default '{}') returns jsonb language sql stable as $$
 select g->'soccer' from jsonb_array_elements(public.boss_games_read(pg_temp.query(label,extra))->'games')g
$$;
revoke all on function pg_temp.sc_game(text),pg_temp.sc_roster(text,text,int),pg_temp.sc_op(text,text,jsonb,text),pg_temp.sc_roster_array(text,text,int),pg_temp.sc_clone_event(text,text),pg_temp.sc_link(text,text,text,text),pg_temp.sc_detail(text,jsonb) from public;
grant execute on function pg_temp.sc_game(text),pg_temp.sc_roster(text,text,int),pg_temp.sc_op(text,text,jsonb,text),pg_temp.sc_roster_array(text,text,int),pg_temp.sc_clone_event(text,text),pg_temp.sc_link(text,text,text,text),pg_temp.sc_detail(text,jsonb) to authenticated,anon;

create function pg_temp.sc_lineup(label text,side text,count_players int default 11,keeper_n int default 1) returns jsonb language sql stable as $$
 select jsonb_build_object('side',side,'roster_ids',pg_temp.sc_roster_array(label,side,count_players))||case when keeper_n=0 then '{}'::jsonb else jsonb_build_object('goalkeeper_roster_id',pg_temp.sc_roster(label,side,keeper_n))end
$$;
create function pg_temp.sc_create(label text,event_label text default 'internal',start_game boolean default true,segments int default 2,enforce boolean default true,lineup_count int default 11,extra_segments int default 0,reentry boolean default true,max_subs int default null) returns void language plpgsql as $$begin
 perform pg_temp.sc_link(label,event_label);
 perform pg_temp.sc_op('soccer.configure',label,jsonb_build_object('regulation_segments',segments,'segment_seconds',60,'extra_time_segments',extra_segments,'extra_time_seconds',60,'lineup_size',lineup_count,'enforce_lineup',enforce,'allow_reentry',reentry,'max_substitutions',max_subs));
 if enforce then
  perform pg_temp.sc_op('soccer.lineup.set',label,pg_temp.sc_lineup(label,'primary',lineup_count));
  if pg_temp.sc_roster(label,'opponent',1) is not null then perform pg_temp.sc_op('soccer.lineup.set',label,pg_temp.sc_lineup(label,'opponent',lineup_count));end if;
 end if;
 if start_game then perform pg_temp.game_op('game.start',label);perform pg_temp.sc_op('soccer.segment.start',label);end if;
end$$;
create function pg_temp.sc_event_id(label text,request text) returns uuid language sql stable security definer set search_path='' as $$
 select id from public.game_soccer_events where game_id=pg_temp.sc_game(label) and request_id=pg_temp.f(request) order by sequence desc limit 1
$$;
create function pg_temp.sc_event(label text,kind text,side text default 'primary',n int default 1,request_label text default null,score_event uuid default null,keeper_n int default 0) returns uuid language plpgsql as $$declare request text;begin
 request:=coalesce(request_label,'sc-event-'||label||'-'||(select version from pg_temp.phase5a_games where phase5a_games.label=sc_event.label));
 perform pg_temp.sc_op('soccer.event.add',label,jsonb_build_object('event_type',kind,'side',side)||
 case when n=0 then '{}'::jsonb else jsonb_build_object('roster_id',pg_temp.sc_roster(label,side,n))end||
 case when score_event is null then '{}'::jsonb else jsonb_build_object('scoring_event_id',score_event)end||
 case when keeper_n=0 then '{}'::jsonb else jsonb_build_object('goalkeeper_roster_id',pg_temp.sc_roster(label,case side when 'primary' then 'opponent' else 'primary' end,keeper_n))end,request);
 return pg_temp.sc_event_id(label,request);
end$$;
create function pg_temp.sc_clock(label text,ms bigint) returns void language plpgsql as $$begin
 perform pg_temp.sc_op('soccer.clock.set',label,jsonb_build_object('clock_ms',ms,'reason','Synthetic monotonic game time'));
end$$;
create function pg_temp.sc_end(label text,ms bigint default 60000) returns void language plpgsql as $$begin
 perform pg_temp.sc_clock(label,ms);perform pg_temp.sc_op('soccer.segment.end',label);
end$$;
create function pg_temp.sc_finish(label text) returns void language plpgsql as $$declare current_segment int;regulation int;begin
 select(pg_temp.sc_detail(label)->>'segment_number')::int,(pg_temp.sc_detail(label)->>'regulation_segments')::int into current_segment,regulation;
 while current_segment<regulation loop perform pg_temp.sc_end(label);perform pg_temp.sc_op('soccer.segment.start',label);current_segment:=current_segment+1;end loop;
 perform pg_temp.sc_end(label);
end$$;
create function pg_temp.sc_box(label text) returns jsonb language sql volatile security definer set search_path='' as $$
 select jsonb_agg(to_jsonb(t)) from boss_private.soccer_totals(pg_temp.sc_game(label))t
$$;
revoke all on function pg_temp.sc_lineup(text,text,int,int),pg_temp.sc_create(text,text,boolean,int,boolean,int,int,boolean,int),pg_temp.sc_event_id(text,text),pg_temp.sc_event(text,text,text,int,text,uuid,int),pg_temp.sc_clock(text,bigint),pg_temp.sc_end(text,bigint),pg_temp.sc_finish(text),pg_temp.sc_box(text) from public;
grant execute on function pg_temp.sc_lineup(text,text,int,int),pg_temp.sc_create(text,text,boolean,int,boolean,int,int,boolean,int),pg_temp.sc_event_id(text,text),pg_temp.sc_event(text,text,text,int,text,uuid,int),pg_temp.sc_clock(text,bigint),pg_temp.sc_end(text,bigint),pg_temp.sc_finish(text),pg_temp.sc_box(text) to authenticated,anon;
