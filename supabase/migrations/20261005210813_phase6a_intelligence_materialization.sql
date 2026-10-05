create function boss_private.stat_reduce(rows jsonb)returns jsonb
language sql immutable set search_path=''as $$
 with entries as(
 select e.key,(e.value#>>'{}')::numeric amount,r->'coverage'->>e.key coverage,coalesce((r->'participation'->>'confirmed')::boolean,false)played
 from jsonb_array_elements(rows)r cross join lateral jsonb_each(r->'components')e
 ),grouped as(
 select key,case when key like'long_%'then max(amount)else sum(amount)end observed,
 case when key like'long_%'then max(amount)filter(where coverage='tracked')else sum(amount)filter(where coverage='tracked')end complete,
 count(*)filter(where coverage='tracked'and amount is not null)full_n,count(*)filter(where coverage='partially_tracked')partial_n,
 count(*)filter(where coalesce(coverage,'legacy_unknown')='legacy_unknown')unknown_n,count(*)filter(where coverage='not_tracked')untracked_n,
 count(*)filter(where coverage='tracked'and played and amount is not null)denom,sum(amount)filter(where coverage='tracked'and played)played_value
 from entries group by key
 )select coalesce(jsonb_object_agg(key,jsonb_build_object('observed_value',observed,'complete_value',complete,'complete_games',full_n,'partial_games',partial_n,'legacy_unknown_games',unknown_n,'untracked_games',untracked_n,'played_complete_games',denom,'played_complete_value',played_value,'per_tracked_game',case when denom>0 and key not like'long_%'then played_value/denom end,'reducer',case when key like'long_%'then'max'else'sum'end)),'{}')from grouped
$$;
create function boss_private.stat_ratio(rows jsonb,keys text[],coefficients numeric[],denominator text[],scale numeric default 1)
returns jsonb language plpgsql immutable set search_path=''as $$
declare numerator numeric:=0;divisor numeric:=0;eligible int:=0;r jsonb;k text;i int;ok boolean;begin
 for r in select *from jsonb_array_elements(rows)loop
 ok:=true;foreach k in array keys||denominator loop
 if r->'coverage'->>k is distinct from'tracked' or jsonb_typeof(r->'components'->k) is distinct from'number'then ok:=false;end if;end loop;
 if ok then
 eligible:=eligible+1;for i in 1..cardinality(keys)loop numerator:=numerator+(r->'components'->>keys[i])::numeric*coefficients[i];end loop;
 foreach k in array denominator loop divisor:=divisor+(r->'components'->>k)::numeric;end loop;
 end if;end loop;
 return jsonb_build_object('value',case when divisor>0 then scale*numerator/divisor end,'numerator',numerator,'denominator',divisor,'scale',scale,'complete_games',eligible,'reason',case when eligible=0 then'no_complete_joint_coverage'when divisor=0 then'no_opportunities'else null end);
end$$;
create function boss_private.stat_rates(sport text,rows jsonb)returns jsonb
language plpgsql immutable set search_path=''as $$
declare v jsonb:='{}';basis int;basis_count int;begin
 if sport='basketball'then
 v:=jsonb_build_object('fg_percentage',boss_private.stat_ratio(rows,array['fgm'],array[1]::numeric[],array['fga'],100),'three_point_percentage',boss_private.stat_ratio(rows,array['tpm'],array[1]::numeric[],array['tpa'],100),'ft_percentage',boss_private.stat_ratio(rows,array['ftm'],array[1]::numeric[],array['fta'],100));
 -- 2PT cohort must include all four shot inputs, not independent rate cohorts.
 v:=v||jsonb_build_object('two_point_percentage',boss_private.stat_ratio(
 (select coalesce(jsonb_agg(r||jsonb_build_object('components',(r->'components')||jsonb_build_object('two_m',(r->'components'->>'fgm')::numeric-(r->'components'->>'tpm')::numeric,'two_a',(r->'components'->>'fga')::numeric-(r->'components'->>'tpa')::numeric),'coverage',(r->'coverage')||jsonb_build_object('two_m','tracked','two_a','tracked'))),'[]')from jsonb_array_elements(rows)r where r->'coverage'->>'fgm'='tracked'and r->'coverage'->>'fga'='tracked'and r->'coverage'->>'tpm'='tracked'and r->'coverage'->>'tpa'='tracked'),array['two_m'],array[1]::numeric[],array['two_a'],100));
 elsif sport='soccer'then
 v:=jsonb_build_object('shots_on_goal_rate',boss_private.stat_ratio(rows,array['shots_on_goal'],array[1]::numeric[],array['shots'],100),'save_percentage',boss_private.stat_ratio(rows,array['saves'],array[1]::numeric[],array['saves','goals_allowed'],100));
 elsif sport='football'then
 v:=jsonb_build_object('completion_percentage',boss_private.stat_ratio(rows,array['passing_completions'],array[1]::numeric[],array['passing_attempts'],100),'passing_yards_per_attempt',boss_private.stat_ratio(rows,array['passing_yards'],array[1]::numeric[],array['passing_attempts']),'yards_per_carry',boss_private.stat_ratio(rows,array['rushing_yards'],array[1]::numeric[],array['rush_attempts']),'yards_per_reception',boss_private.stat_ratio(rows,array['receiving_yards'],array[1]::numeric[],array['receptions']),'punt_average',boss_private.stat_ratio(rows,array['punt_yards'],array[1]::numeric[],array['punts']),'field_goal_percentage',boss_private.stat_ratio(rows,array['field_goals_made'],array[1]::numeric[],array['field_goals_attempted'],100),'extra_point_percentage',boss_private.stat_ratio(rows,array['extra_points_made'],array[1]::numeric[],array['extra_points_attempted'],100));
 elsif sport='volleyball'then
 v:=jsonb_build_object('hitting_percentage',boss_private.stat_ratio(rows,array['kills','attack_errors'],array[1,-1]::numeric[],array['attack_attempts']));
 elsif sport in('baseball','softball')then
 select count(distinct(r->>'era_basis_innings')::int),min((r->>'era_basis_innings')::int)into basis_count,basis from jsonb_array_elements(rows)r;
 v:=jsonb_build_object('avg',boss_private.stat_ratio(rows,array['hits'],array[1]::numeric[],array['ab']),'obp',boss_private.stat_ratio(rows,array['hits','walks','hbp'],array[1,1,1]::numeric[],array['ab','walks','hbp','sacrifice_flies']),'slg',boss_private.stat_ratio(rows,array['singles','doubles','triples','home_runs'],array[1,2,3,4]::numeric[],array['ab']),'whip',boss_private.stat_ratio(rows,array['walks_allowed','hits_allowed'],array[1,1]::numeric[],array['outs_pitched'],3),'strike_percentage',boss_private.stat_ratio(rows,array['strikes'],array[1]::numeric[],array['pitches'],100),'era',case when basis_count=1 then boss_private.stat_ratio(rows,array['earned_runs'],array[1]::numeric[],array['outs_pitched'],basis*3)else jsonb_build_object('value',null,'reason','mixed_or_unknown_era_convention')end,'era_basis_innings',case when basis_count=1 then basis end);
 -- OPS uses a single common cohort for both OBP and SLG.
 select coalesce(jsonb_agg(r),'[]')into rows from jsonb_array_elements(rows)r where not exists(select 1 from unnest(array['hits','walks','hbp','ab','sacrifice_flies','singles','doubles','triples','home_runs'])k where r->'coverage'->>k is distinct from'tracked' or jsonb_typeof(r->'components'->k)is distinct from'number');
 v:=v||jsonb_build_object('ops',jsonb_build_object('value',(boss_private.stat_ratio(rows,array['hits','walks','hbp'],array[1,1,1]::numeric[],array['ab','walks','hbp','sacrifice_flies'])->>'value')::numeric+(boss_private.stat_ratio(rows,array['singles','doubles','triples','home_runs'],array[1,2,3,4]::numeric[],array['ab'])->>'value')::numeric,'complete_games',jsonb_array_length(rows),'obp',boss_private.stat_ratio(rows,array['hits','walks','hbp'],array[1,1,1]::numeric[],array['ab','walks','hbp','sacrifice_flies']),'slg',boss_private.stat_ratio(rows,array['singles','doubles','triples','home_runs'],array[1,2,3,4]::numeric[],array['ab'])));
 end if;return v;
end$$;

create function boss_private.stat_invalidate()returns trigger language plpgsql security definer set search_path=''as $$
declare gid uuid;org uuid;begin
 gid:=new.id;org:=new.organization_id;
 if TG_OP='UPDATE'and new.status is not distinct from old.status and new.finalization_count=old.finalization_count then return new;end if;
 insert into public.stat_game_selections(game_id,organization_id)values(gid,org)on conflict(game_id)do update set generation=public.stat_game_selections.generation+1,changed_at=clock_timestamp();
 insert into public.stat_refresh_work(game_id,target_generation)select game_id,generation from public.stat_game_selections where game_id=gid on conflict(game_id)do update set target_generation=excluded.target_generation;
 -- Scope freshness is invalidated through generation/work; do not invert summary locks.

 return new;
end$$;
create trigger stat_game_invalidate after insert or update of status,finalization_count on public.games for each row execute function boss_private.stat_invalidate();
-- Existing sources get dirty selectors only; classification is deliberately pending.
insert into public.stat_game_selections(game_id,organization_id)select id,organization_id from public.games;
insert into public.stat_refresh_work(game_id,target_generation)select game_id,generation from public.stat_game_selections;

create function boss_private.stat_refresh(p_game uuid,p_full_rebuild boolean default false)returns boolean
language plpgsql volatile security definer set search_path=''as $$
declare g public.games;f public.game_finalizations;cl public.stat_competition_classifications;sel public.stat_game_selections;s record;r public.game_roster_snapshots;t public.game_finalization_tracking_seals;dimension record;data jsonb;watermark text;payload jsonb;begin
 -- Canonical lock order; no summary lock precedes a game lock.
 perform 1 from public.events e join public.games gg on gg.event_id=e.id where gg.id=p_game for update of e;
 select *into g from public.games where id=p_game for update;
 if g.id is null then raise exception 'Game unavailable'using errcode='PT403';end if;
 select *into sel from public.stat_game_selections where game_id=g.id for update;
 if sel.refreshed_generation=sel.generation then return true;end if;
 if g.status='final'then
 select *into f from public.game_finalizations where game_id=g.id and epoch=g.finalization_count;
 if f.id is null then return false;end if;
 select *into cl from public.stat_competition_classifications where game_id=g.id and applies_epoch<=f.epoch order by version desc limit 1;
 if cl.classification='official'and not exists(select 1 from boss_private.stat_sealed_rows(f.id))then return false;end if;
 if cl.classification='official'and exists(select 1 from boss_private.stat_sealed_rows(f.id)src join public.game_roster_snapshots rs on rs.id=src.roster_id group by rs.person_id having count(*)>1)then return false;end if;
 for s in select *from boss_private.stat_sealed_rows(f.id)loop
 r:=null;t:=null;
 if s.roster_id is not null then
 select *into r from public.game_roster_snapshots where id=s.roster_id and game_id=g.id and organization_id=g.organization_id and revision=f.roster_revision;
 if r.id is null or r.person_id is null or r.participant_id is null or r.team_id is distinct from (case s.side when'primary'then g.primary_team_id else g.opponent_team_id end) then raise exception 'Sealed provenance mismatch'using errcode='PT409';end if;end if;
 select *into t from public.game_finalization_tracking_seals where finalization_id=f.id and organization_id=g.organization_id and game_id=g.id and side=s.side;
 insert into public.stat_game_contributions(organization_id,game_id,finalization_id,epoch,roster_revision,side,team_id,roster_id,person_id,participant_id,season_id,sport_key,engine_version,classification_id,classification,source_stat_id,tracking_snapshot_id,components,coverage,participation,era_basis_innings)
 values(g.organization_id,g.id,f.id,f.epoch,f.roster_revision,s.side,case s.side when'primary'then g.primary_team_id else g.opponent_team_id end,s.roster_id,r.person_id,r.participant_id,g.season_id,g.sport_key,s.engine_version,cl.id,coalesce(cl.classification,'pending'),s.source_stat_id,t.snapshot_id,
 boss_private.stat_components(s.components,coalesce(t.coverage,'{}'),r.id is not null)||case when r.id is null then jsonb_build_object('scoring_for',case s.side when'primary'then f.primary_score else f.opponent_score end,'scoring_against',case s.side when'primary'then f.opponent_score else f.primary_score end)else'{}'::jsonb end,boss_private.stat_metric_coverage(s.components,coalesce(t.coverage,'{}'),r.id is not null)||case when r.id is null then'{"scoring_for":"tracked","scoring_against":"tracked"}'::jsonb else'{}'::jsonb end,boss_private.stat_participation(g.id,f.id,r.id,s.components),
 case when g.sport_key in('baseball','softball')then coalesce((s.engine_state->'configuration'->>'era_innings')::int,case g.sport_key when'baseball'then 9 else 7 end)end)on conflict do nothing;
 end loop;
 end if;
 update public.stat_game_selections set finalization_id=f.id where game_id=g.id;
 -- Refresh every old/new origin dimension, including those removed on reopen.
 for dimension in select distinct organization_id,team_id,sport_key,season_id,person_id from public.stat_game_contributions where game_id=g.id and team_id is not null order by organization_id,team_id,sport_key,season_id,person_id loop
 -- Never wait for a summary owner while retaining canonical game locks.
 if not pg_try_advisory_xact_lock(hashtextextended('boss-stat-origin:'||row(dimension.organization_id,dimension.team_id,dimension.sport_key,dimension.season_id,dimension.person_id)::text,0))then return false;end if;
 -- Refuse an unbounded synchronous reduction; selectors stay dirty/pending.
 if not p_full_rebuild and (select count(*)from(select 1 from public.stat_game_contributions c join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id where c.organization_id=dimension.organization_id and c.team_id=dimension.team_id and c.sport_key=dimension.sport_key and c.season_id is not distinct from dimension.season_id and c.person_id is not distinct from dimension.person_id and c.classification='official'limit 2001)bounded)>2000 then return false;end if;

 select coalesce(jsonb_agg(to_jsonb(c)order by c.game_id,c.id),'[]'),md5(coalesce(string_agg(c.finalization_id::text||':'||gs.generation::text,',' order by c.game_id,c.id),''))into data,watermark
 from public.stat_game_contributions c join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id
 join public.games cg on cg.id=c.game_id and cg.status='final' and cg.finalization_count=c.epoch
 where c.organization_id=dimension.organization_id and c.team_id=dimension.team_id and c.sport_key=dimension.sport_key and c.season_id is not distinct from dimension.season_id and c.person_id is not distinct from dimension.person_id and c.classification='official';
 payload:=jsonb_build_object('source_game_count',jsonb_array_length(data),'confirmed_gp',(select count(*)from jsonb_array_elements(data)x where(x->'participation'->>'confirmed')::boolean),'participation_partial_games',(select count(*)from jsonb_array_elements(data)x where x->'participation'->>'coverage'='partial'),'era_conventions',(select coalesce(jsonb_agg(distinct(x->>'era_basis_innings')::int)filter(where x->>'era_basis_innings'is not null),'[]')from jsonb_array_elements(data)x),'participation_unknown_games',(select count(*)from jsonb_array_elements(data)x where x->'participation'->>'coverage'='unknown'),'metrics',boss_private.stat_reduce(data),'rates',boss_private.stat_rates(dimension.sport_key,data));
 insert into public.stat_origin_summaries(organization_id,team_id,sport_key,season_id,person_id,generation,is_current,source_watermark,refreshed_at,summary)
 values(dimension.organization_id,dimension.team_id,dimension.sport_key,dimension.season_id,dimension.person_id,1,true,watermark,clock_timestamp(),payload)
 on conflict(organization_id,team_id,sport_key,season_id,person_id,definition_version)do update set generation=public.stat_origin_summaries.generation+1,is_current=true,source_watermark=excluded.source_watermark,refreshed_at=excluded.refreshed_at,summary=excluded.summary;
 end loop;
 update public.stat_game_selections set refreshed_generation=generation,refreshed_at=clock_timestamp()where game_id=g.id;
 delete from public.stat_refresh_work where game_id=g.id and target_generation=sel.generation;
 return true;
end$$;
create function boss_private.stat_eager_refresh()returns trigger language plpgsql security definer set search_path=''as $$
begin
 -- Deferred until all sport/coverage seals exist; bounded affected roster only.
 if (select count(*)from public.game_roster_snapshots where game_id=new.id and revision=new.roster_revision)<=50 then perform boss_private.stat_refresh(new.id);end if;
 return null;
end$$;
create constraint trigger stat_eager_refresh after insert or update on public.games deferrable initially deferred for each row execute function boss_private.stat_eager_refresh();
do $$declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'stat_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.sig);end loop;end$$;
