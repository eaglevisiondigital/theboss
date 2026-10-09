-- Narrow hosted fix: avoid the mv PL/pgSQL variable/SQL alias ambiguity.
-- No identity, authorization, scoring or architecture change.
create or replace function boss_private.diamond_totals(p_game uuid)returns table(side text,roster_id uuid,stats jsonb)
language plpgsql stable security definer set search_path=''as $$
declare c jsonb;s jsonb;n jsonb;m jsonb:='{}';zero jsonb:='{}';ev public.game_diamond_events;pa jsonb;runner jsonb;mv jsonb;bat text;def text;batter text;pitcher text;result text;k text;subject text;rid text;r public.game_roster_snapshots;run_delta int;out_delta int;counter text;seen_double_plays text[]:='{}';count_keys text[]:=array['pa','ab','runs','hits','singles','doubles','triples','home_runs','rbi','walks','hbp','strikeouts','stolen_bases','caught_stealing','sacrifice_flies','sacrifice_bunts','outs_pitched','batters_faced','hits_allowed','runs_allowed','earned_runs','walks_allowed','strikeouts_pitched','hbp_allowed','home_runs_allowed','pitches','strikes','wild_pitches','putouts','assists','errors','double_plays'];begin
 select configuration into c from public.game_diamond_states where game_id=p_game;s:=boss_private.diamond_initial(c);
 select jsonb_object_agg(x,0)into zero from unnest(count_keys)x;
 m:=jsonb_build_object('primary:team',zero,'opponent:team',zero);
 for r in select *from public.game_roster_snapshots where game_id=p_game and revision=(select ds.roster_revision from public.game_diamond_states ds where ds.game_id=p_game)loop
 select case when r.team_id=g.primary_team_id then'primary'else'opponent'end into bat from public.games g where g.id=p_game;
 m:=jsonb_set(m,array[bat||':'||r.id],zero);end loop;
 for ev in select *from boss_private.diamond_active_events(p_game)loop
 if ev.event_type='configure'then continue;end if;
 bat:=s->>'batting_side';def:=s->>'defensive_side';pa:=s->'pa';batter:=pa->>'batter';pitcher:=s->'pitchers'->>def;result:=ev.payload->>'result';
 n:=boss_private.diamond_transition(c,s,ev.payload);
 run_delta:=(n->>(bat||'_score'))::int-(s->>(bat||'_score'))::int;
 -- A half-ending transition retains outs until the next explicit half start.
 out_delta:=(n->>'outs')::int-(s->>'outs')::int;
 if ev.event_type in('play','advance')then
 m:=boss_private.diamond_counter(m,def,pitcher,'outs_pitched',out_delta);
 if run_delta>0 then
 -- Credit only scoring movements that survived third-out legal ordering.
 for mv in select value from jsonb_array_elements(ev.payload->'moves')where not(value->>'out')::boolean and value->>'to'='4'loop
 runner:=case when mv->>'from'='0'then jsonb_build_object('roster_id',pa->'batter','responsible_pitcher',pa->'pitcher','placed',false)else s->'bases'->((mv->>'from')::int-1)end;
 m:=boss_private.diamond_counter(m,bat,runner->>'roster_id','runs',1);
 m:=boss_private.diamond_counter(m,def,runner->>'responsible_pitcher','runs_allowed',1);
 if coalesce((mv->>'earned')::boolean,false)and not coalesce((runner->>'placed')::boolean,false)then m:=boss_private.diamond_counter(m,def,runner->>'responsible_pitcher','earned_runs',1);end if;
 if ev.event_type='play'and coalesce((mv->>'rbi')::boolean,result in('single','double','triple','home_run','walk','intentional_walk','hit_by_pitch','sacrifice_bunt','sacrifice_fly'))then m:=boss_private.diamond_counter(m,bat,batter,'rbi',1);end if;
 end loop;end if;
 if ev.event_type='advance'then
 for mv in select value from jsonb_array_elements(ev.payload->'moves')loop
 runner:=s->'bases'->((mv->>'from')::int-1);
 if mv->>'cause'in('stolen_base','caught_stealing')and boss_private.tracking_at(p_game,bat,case mv->>'cause'when'stolen_base'then'stolen_bases'else'caught_stealing'end,ev.origin_sequence)then
 m:=boss_private.diamond_counter(m,bat,runner->>'roster_id',case mv->>'cause'when'stolen_base'then'stolen_bases'else'caught_stealing'end,1);end if;end loop;
 if exists(select 1 from jsonb_array_elements(ev.payload->'moves') movement_row(value) where movement_row.value->>'cause'='wild_pitch')then m:=boss_private.diamond_counter(m,def,pitcher,'wild_pitches',1);end if;
 else
 pitcher:=pa->>'pitcher';m:=boss_private.diamond_counter(m,bat,batter,'pa',1);m:=boss_private.diamond_counter(m,def,pitcher,'batters_faced',1);
 if result not in('walk','intentional_walk','hit_by_pitch','sacrifice_bunt','sacrifice_fly','catcher_interference')then m:=boss_private.diamond_counter(m,bat,batter,'ab',1);end if;
 if result in('single','double','triple','home_run')then
 m:=boss_private.diamond_counter(m,bat,batter,'hits',1);m:=boss_private.diamond_counter(m,def,pitcher,'hits_allowed',1);
 counter:=case result when'single'then'singles'when'double'then'doubles'when'triple'then'triples'else'home_runs'end;m:=boss_private.diamond_counter(m,bat,batter,counter,1);
 if result='home_run'then m:=boss_private.diamond_counter(m,def,pitcher,'home_runs_allowed',1);end if;end if;
 if result in('walk','intentional_walk')then m:=boss_private.diamond_counter(m,bat,batter,'walks',1);m:=boss_private.diamond_counter(m,def,pitcher,'walks_allowed',1);end if;
 if result='hit_by_pitch'then m:=boss_private.diamond_counter(m,bat,batter,'hbp',1);m:=boss_private.diamond_counter(m,def,pitcher,'hbp_allowed',1);end if;
 if result in('strikeout','dropped_third_strike')then m:=boss_private.diamond_counter(m,bat,batter,'strikeouts',1);m:=boss_private.diamond_counter(m,def,pitcher,'strikeouts_pitched',1);end if;
 if result in('sacrifice_bunt','sacrifice_fly')then m:=boss_private.diamond_counter(m,bat,batter,case result when'sacrifice_bunt'then'sacrifice_bunts'else'sacrifice_flies'end,1);end if;
 end if;
 elsif ev.event_type='fielding'then
 m:=boss_private.diamond_counter(m,ev.payload->>'side',ev.payload->>'roster_id',ev.payload->>'stat',1);
 if ev.payload->>'stat'='double_plays'then
 if ev.payload->>'play_event_id'=any(seen_double_plays)then m:=jsonb_set(m,array[(ev.payload->>'side')||':team','double_plays'],to_jsonb((m->((ev.payload->>'side')||':team')->>'double_plays')::int-1));else seen_double_plays:=array_append(seen_double_plays,ev.payload->>'play_event_id');end if;end if;
 elsif ev.event_type='pitch'then
 m:=boss_private.diamond_counter(m,def,pitcher,'pitches',1);
 if ev.payload->>'outcome'<>'ball'then m:=boss_private.diamond_counter(m,def,pitcher,'strikes',1);end if;
 end if;s:=n;
 end loop;
 for subject in select jsonb_object_keys(m)loop
 side:=split_part(subject,':',1);rid:=split_part(subject,':',2);roster_id:=case rid when'team'then null::uuid else rid::uuid end;
 stats:=boss_private.diamond_stat_rates(m->subject,(c->>'era_innings')::int);return next;end loop;
end$$;
revoke all on function boss_private.diamond_totals(uuid) from public,anon,authenticated,service_role;
