-- Values come only from immutable sport seals; facts are inspected solely for GP evidence.
create function boss_private.stat_sealed_rows(p_final uuid)
returns table(source_stat_id uuid,side text,roster_id uuid,components jsonb,engine_version text,engine_state jsonb)
language sql stable security definer set search_path='' as $$
 select s.id,s.side,s.roster_id,to_jsonb(s)-array['id','finalization_id','organization_id','game_id','side','roster_id'],f.engine_version,f.state
 from public.game_basketball_final_stats s join public.game_basketball_finalizations f using(finalization_id) where s.finalization_id=p_final
 union all select s.id,s.side,s.roster_id,to_jsonb(s)-array['id','finalization_id','organization_id','game_id','side','roster_id'],f.engine_version,f.state
 from public.game_soccer_final_stats s join public.game_soccer_finalizations f using(finalization_id) where s.finalization_id=p_final
 union all select s.id,s.side,s.roster_id,s.stats,f.engine_version,f.state from public.game_football_final_stats s join public.game_football_finalizations f using(finalization_id) where s.finalization_id=p_final
 union all select s.id,s.side,s.roster_id,s.stats,f.engine_version,f.state from public.game_volleyball_final_stats s join public.game_volleyball_finalizations f using(finalization_id) where s.finalization_id=p_final
 union all select s.id,s.side,s.roster_id,s.stats,f.engine_version,f.state from public.game_diamond_final_stats s join public.game_diamond_finalizations f using(finalization_id) where s.finalization_id=p_final
$$;
create function boss_private.stat_participation(p_game uuid,p_final uuid,p_roster uuid,p_stats jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare g public.games;f public.game_finalizations;cut bigint;start_seq bigint;played boolean:=false;complete boolean:=false;begin
 if p_roster is null then return '{"confirmed":true,"coverage":"complete","evidence":"team_final"}'::jsonb;end if;
 select *into g from public.games where id=p_game;select *into f from public.game_finalizations where id=p_final and game_id=p_game;
 if f.id is null then raise exception 'Invalid sealed participation'using errcode='PT409';end if;
 cut:=f.operation_sequence;
 select min(sequence)into start_seq from public.game_operations where game_id=g.id and operation='game.start'and sequence<cut;
 -- Finite count/participation components. Never use rates, roster or position labels.
 select exists(select 1 from jsonb_each(p_stats)x where jsonb_typeof(x.value)='number' and(x.value#>>'{}')::numeric<>0
 and x.key=any(array['points','offensive_rebounds','defensive_rebounds','assists','steals','blocks','turnovers','personal_fouls','fga','fta','goals','own_goals','shots','saves','yellow_cards','red_cards','fouls','minutes','passing_attempts','rush_attempts','receptions','targets','tackles','sacks','defensive_interceptions','fumbles','fumble_recoveries','field_goals_attempted','extra_points_attempted','punts','kick_returns','punt_returns','kills','attack_attempts','digs','service_attempts','service_aces','receptions','pa','batters_faced','outs_pitched','putouts','errors','stolen_bases','caught_stealing','runs'])) into played;
 if g.sport_key='soccer' then
 select coalesce((state->>'participation_complete')::boolean,false)into complete from public.game_soccer_finalizations where finalization_id=f.id;
 if p_stats->>'minutes' is null then complete:=false;end if;
 end if;
 -- Accepted facts at the sealed cutoff; superseded/reversed leaves do not count.
 if not played then
 if g.sport_key='basketball' then
 select exists(select 1 from public.game_basketball_events e where e.game_id=g.id and e.sequence<cut and (e.sequence>=start_seq or(e.event_type in('lineup_set')and e.sequence=(select max(pre.sequence)from public.game_basketball_events pre where pre.game_id=g.id and pre.side=e.side and pre.event_type=e.event_type and pre.sequence<start_seq)))and e.event_type<>all(array['engine_configure','reversal','clock_set','clock_start','clock_stop','period_start','period_end'])
 and(e.roster_id=p_roster or e.secondary_roster_id=p_roster or exists(select 1 from public.game_basketball_lineup_history h where h.event_id=e.id and h.roster_id=p_roster))
 and not exists(select 1 from public.game_basketball_events c where c.game_id=e.game_id and c.correction_of=e.id and c.sequence<cut))into played;
 elsif g.sport_key='soccer' then
 select exists(select 1 from public.game_soccer_events e where e.game_id=g.id and e.sequence<cut and (e.sequence>=start_seq or(e.event_type in('lineup_set','keeper_set')and e.sequence=(select max(pre.sequence)from public.game_soccer_events pre where pre.game_id=g.id and pre.side=e.side and pre.event_type=e.event_type and pre.sequence<start_seq)))and e.event_type<>all(array['engine_configure','reversal','clock_set','clock_start','clock_stop','segment_start','segment_end','added_time_set'])
 and(e.roster_id=p_roster or e.secondary_roster_id=p_roster or e.goalkeeper_roster_id=p_roster or p_roster=any(e.lineup_roster_ids))
 and not exists(select 1 from public.game_soccer_events c where c.game_id=e.game_id and c.correction_of=e.id and c.sequence<cut))into played;
 elsif g.sport_key='football' then
 select exists(select 1 from public.game_football_events e where e.game_id=g.id and e.sequence<cut and (e.sequence>=start_seq or(e.event_type in('lineup_set')and e.sequence=(select max(pre.sequence)from public.game_football_events pre where pre.game_id=g.id and pre.side=e.side and pre.event_type=e.event_type and pre.sequence<start_seq)))and e.event_type not in('engine_configure','reversal','state_set','period_start','period_end','clock_start','clock_stop','clock_set')
 and(e.roster_id=p_roster or jsonb_path_exists(e.payload,'$.** ? (@ == $rid)',jsonb_build_object('rid',p_roster::text)))
 and not exists(select 1 from public.game_football_events c where c.game_id=e.game_id and c.correction_of=e.id and c.sequence<cut))into played;
 elsif g.sport_key='volleyball' then
 select exists(select 1 from public.game_volleyball_events e where e.game_id=g.id and e.sequence<cut and (e.sequence>=start_seq or(e.event_type in('lineup_set')and e.sequence=(select max(pre.sequence)from public.game_volleyball_events pre where pre.game_id=g.id and pre.side=e.side and pre.event_type=e.event_type and pre.sequence<start_seq)))and e.event_type not in('configure','reversal')
 and jsonb_path_exists(e.payload,'$.** ? (@ == $rid)',jsonb_build_object('rid',p_roster::text))
 and not exists(select 1 from public.game_volleyball_events c where c.game_id=e.game_id and c.correction_of=e.id and c.sequence<cut))into played;
 else
 select exists(select 1 from public.game_diamond_events e where e.game_id=g.id and e.sequence<cut and (e.sequence>=start_seq or(e.event_type in('lineup_set')and e.sequence=(select max(pre.sequence)from public.game_diamond_events pre where pre.game_id=g.id and pre.payload->>'side'=e.payload->>'side' and pre.event_type=e.event_type and pre.sequence<start_seq)))and e.event_type not in('configure','reversal','pitch')
 and jsonb_path_exists(e.payload,'$.** ? (@ == $rid)',jsonb_build_object('rid',p_roster::text))
 and not exists(select 1 from public.game_diamond_events c where c.game_id=e.game_id and c.correction_of=e.id and c.sequence<cut))into played;
 end if;end if;
 return jsonb_build_object('confirmed',played,'coverage',case when complete then'complete'when played then'partial'else'unknown'end,'evidence',case when played then'accepted_sport_participation'when complete then'complete_no_appearance'else'insufficient'end);
end$$;
create function boss_private.stat_components(p_raw jsonb,p_coverage jsonb,p_player boolean)
returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(x.key,case when p_coverage->>x.key='not_tracked' or(p_player and(p_coverage->>'player_attribution'='not_tracked' or x.key in('set_wins') or x.key='points' and p_raw?'attack_attempts'))then 'null'::jsonb when x.key='clean_sheet'and jsonb_typeof(x.value)='boolean'then to_jsonb(case when(x.value#>>'{}')::boolean then 1 else 0 end)else x.value end),'{}')
 from jsonb_each(p_raw)x where x.key<>all(array['avg','obp','slg','ops','era','whip','strike_percentage','hitting_percentage'])
$$;
create function boss_private.stat_metric_coverage(p_raw jsonb,p_coverage jsonb,p_player boolean)
returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(x.key,case
 when p_coverage->>x.key='not_tracked' or(p_player and(p_coverage->>'player_attribution'='not_tracked' or x.key='set_wins' or x.key='points' and p_raw?'attack_attempts'))then'not_tracked'
 when p_coverage->>x.key is null then'legacy_unknown'
 when p_player and p_coverage->>'player_attribution'='partially_tracked'then'partially_tracked'
 when p_player then coalesce(p_coverage->'player_stat_coverage'->>x.key,p_coverage->>x.key)
 else p_coverage->>x.key end),'{}') from jsonb_each(p_raw)x
 where x.key<>all(array['avg','obp','slg','ops','era','whip','strike_percentage','hitting_percentage'])
$$;
do $$declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'stat_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.sig);end loop;end$$;
