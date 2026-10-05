-- Disposable synthetic roster depth; no Football engine is configured here.
\ir ../phase5d/fixture.sql
update public.organization_modules set configuration=configuration||'{"volleyball_live_scoring":true,"volleyball_stats":true,"volleyball_play_by_play":true,"volleyball_lineups":true}'where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
create function pg_temp.vv_profile(label text,side text,preset text default'full',enabled jsonb default'[]',quick jsonb default null)returns jsonb language plpgsql as $$
declare command jsonb;result jsonb;begin
 command:=jsonb_build_object('sport_key','volleyball','scope_type','game','organization_id',pg_temp.f('org'),'game_id',pg_temp.ff_game(label),'side',side,'expected_profile_version',pg_temp.vv_profile_version(pg_temp.ff_game(label),side),'expected_game_version',(select version from pg_temp.phase5a_games where phase5a_games.label=vv_profile.label),'preset',preset,'enabled',enabled,'reason','Synthetic controlled tracking selection');
 if quick is not null then command:=command||jsonb_build_object('quick',quick);end if;
 result:=public.boss_games_mutate(gen_random_uuid(),pg_temp.cmd('tracking.profile.set',command));
 if result->>'version'is not null then update pg_temp.phase5a_games set version=(result->>'version')::bigint where phase5a_games.label=vv_profile.label;end if;
 return result;end$$;
create function pg_temp.vv_create(label text,enforce boolean default false)returns void language plpgsql as $$begin
 perform pg_temp.ff_link(label,'internal','falcons','volleyball');
 perform pg_temp.vv_profile(label,'primary');perform pg_temp.vv_profile(label,'opponent');
 perform pg_temp.game_op('volleyball.configure',label,jsonb_build_object('configuration',jsonb_build_object('best_of',3,'normal_target',3,'deciding_target',2,'win_by_two',true,'court_size',2,'strict_rotation',enforce,'enforce_lineup',enforce,'allow_reentry',true,'libero_enabled',true,'libero_can_serve',false,'substitution_limit',3)));
 if enforce then
 perform pg_temp.game_op('volleyball.lineup.set',label,jsonb_build_object('side','primary','payload',jsonb_build_object('roster_ids',jsonb_build_array(pg_temp.ff_roster(label,'primary',1),pg_temp.ff_roster(label,'primary',2)))));
 perform pg_temp.game_op('volleyball.lineup.set',label,jsonb_build_object('side','opponent','payload',jsonb_build_object('roster_ids',jsonb_build_array(pg_temp.ff_roster(label,'opponent',1),pg_temp.ff_roster(label,'opponent',2)))));end if;
 perform pg_temp.game_op('game.start',label);perform pg_temp.game_op('volleyball.set.start',label,'{"side":"primary"}');end$$;
create function pg_temp.vv_add(label text,kind text,side text,payload jsonb default'{}',request_label text default null)returns uuid language plpgsql as $$declare result jsonb;begin
 result:=pg_temp.game_op('volleyball.event.add',label,jsonb_build_object('event_type',kind,'side',side,'payload',payload),request_label);return(result->>'event_id')::uuid;end$$;
create function pg_temp.vv_stats(label text,side text,n integer default 0)returns jsonb language sql security definer set search_path=''as $$select stats from boss_private.volleyball_totals(pg_temp.ff_game(label))t where t.side=vv_stats.side and t.roster_id is not distinct from case n when 0 then null::uuid else pg_temp.ff_roster(label,side,n)end$$;
create function pg_temp.vv_event(label text,kind text)returns uuid language sql security definer set search_path=''as $$select e.id from boss_private.volleyball_active_events(pg_temp.ff_game(label))e where e.event_type=kind order by e.origin_sequence limit 1$$;
revoke all on function pg_temp.vv_event(text,text)from public;grant execute on function pg_temp.vv_event(text,text)to authenticated;
revoke all on function pg_temp.vv_profile(text,text,text,jsonb,jsonb),pg_temp.vv_create(text,boolean),pg_temp.vv_add(text,text,text,jsonb,text),pg_temp.vv_stats(text,text,integer)from public;
grant execute on function pg_temp.vv_profile(text,text,text,jsonb,jsonb),pg_temp.vv_create(text,boolean),pg_temp.vv_add(text,text,text,jsonb,text),pg_temp.vv_stats(text,text,integer)to authenticated,anon;
-- Fixture helpers can read configuration versions only in this local transaction.
create function pg_temp.vv_profile_version(p_game uuid,side text)returns bigint language sql security definer set search_path=''as $$select coalesce((select version from public.game_tracking_profiles where game_id=p_game and game_tracking_profiles.side=vv_profile_version.side),0)$$;
revoke all on function pg_temp.vv_profile_version(uuid,text)from public;grant execute on function pg_temp.vv_profile_version(uuid,text)to authenticated;
