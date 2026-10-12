-- Rebuildable projections. Source locks always precede edition publication fences.
create function boss_private.ranking_active_rulings(edition uuid)returns setof public.competition_rulings language sql volatile security definer set search_path=''as $$
 select r.*from public.competition_rulings r where r.edition_id=edition and r.effective_at<=clock_timestamp()and r.kind<>'reversal'and not exists(select 1 from public.competition_rulings rev where rev.reversal_of_id=r.id and rev.effective_at<=clock_timestamp())
$$;
create function boss_private.ranking_results(edition uuid)returns jsonb language sql volatile security definer set search_path=''as $$
 with policy as(select coalesce(p.configuration,'{}')c from public.competition_editions e left join public.standings_policy_revisions p on p.id=e.standings_policy_id where e.id=edition),
 assignments as(select *from boss_private.ranking_latest_assignments(edition)where status='active'and counts_for_standings),
 rulings as(select *from boss_private.ranking_active_rulings(edition)),
 overlays as(select distinct on(a.game_id)r.*,a.game_id from rulings r join public.competition_game_assignments a on a.id=r.assignment_id where r.kind in('forfeit','result_override','vacated')order by a.game_id,r.effective_at desc,r.created_at desc,r.id desc),
 ordinary as(select a.id,a.primary_entry_id,a.opponent_entry_id,a.group_id,a.game_id,g.sport_key,f.id finalization_id,f.epoch,
 case when r.id is not null then r.outcome else case when f.tied then'tie'else f.winner_side end end outcome,r.id ruling_id,r.kind ruling_kind,
 case when r.kind='forfeit'then coalesce(r.standings_primary_score,(p.c->'forfeit_score'->>case when r.outcome='opponent'then 1 else 0 end)::int)else coalesce(r.standings_primary_score,f.primary_score)end pf,
 case when r.kind='forfeit'then coalesce(r.standings_opponent_score,(p.c->'forfeit_score'->>case when r.outcome='opponent'then 0 else 1 end)::int)else coalesce(r.standings_opponent_score,f.opponent_score)end pa,
 case when r.id is null then (select sum((s->>'primary_points')::numeric)from jsonb_array_elements(v.state->'sets')s)end primary_points,
 case when r.id is null then (select sum((s->>'opponent_points')::numeric)from jsonb_array_elements(v.state->'sets')s)end opponent_points
 from assignments a join public.games g on g.id=a.game_id left join public.stat_game_selections gs on gs.game_id=g.id left join public.game_finalizations f on f.id=gs.finalization_id and f.epoch=g.finalization_count left join public.game_volleyball_finalizations v on v.finalization_id=f.id left join overlays r on r.game_id=g.id cross join policy p
 where (r.kind in('forfeit','result_override')or(g.status='final'and f.id is not null and gs.generation=gs.refreshed_generation))and r.kind is distinct from'vacated'),
 unplayed as(select r.id,r.primary_entry_id,r.opponent_entry_id,r.group_id,null::uuid game_id,e.sport_key,null::uuid finalization_id,null::bigint epoch,r.outcome,r.id ruling_id,r.kind ruling_kind,
 coalesce(r.standings_primary_score,(p.c->'forfeit_score'->>case when r.outcome='opponent'then 1 else 0 end)::int)pf,
 coalesce(r.standings_opponent_score,(p.c->'forfeit_score'->>case when r.outcome='opponent'then 0 else 1 end)::int)pa,null::numeric primary_points,null::numeric opponent_points
 from rulings r join public.competition_editions e on e.id=r.edition_id cross join policy p where r.assignment_id is null and r.kind='forfeit'),
 combined as(select *from ordinary union all select *from unplayed)
 select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('group_ids',coalesce((select jsonb_agg(distinct x.g)from(select ag.group_id g from public.competition_game_assignment_groups ag where ag.assignment_id=c.id union select c.group_id where c.group_id is not null)x),'[]'))order by c.id),'[]')from combined c
$$;
create function boss_private.ranking_sides(results jsonb)returns table(entry text,opponent text,outcome text,pf numeric,pa numeric,point_for numeric,point_against numeric,groups jsonb)
language sql immutable set search_path=''as $$
 select r->>'primary_entry_id',r->>'opponent_entry_id',case r->>'outcome'when'primary'then'win'when'opponent'then'loss'else'tie'end,(r->>'pf')::numeric,(r->>'pa')::numeric,(r->>'primary_points')::numeric,(r->>'opponent_points')::numeric,r->'group_ids'from jsonb_array_elements(results)r
 union all select r->>'opponent_entry_id',r->>'primary_entry_id',case r->>'outcome'when'opponent'then'win'when'primary'then'loss'else'tie'end,(r->>'pa')::numeric,(r->>'pf')::numeric,(r->>'opponent_points')::numeric,(r->>'primary_points')::numeric,r->'group_ids'from jsonb_array_elements(results)r
$$;
create function boss_private.ranking_tiebreak_value(candidate jsonb,cohort text[],results jsonb,rule jsonb,policy jsonb)returns numeric
language plpgsql immutable set search_path=''as $$
declare mode text:=rule->>'type';id text:=candidate->>'entry_id';opponents text[];needed int:=coalesce((rule->>'minimum_meetings')::int,1);n int;small int;large int;answer numeric;begin
 if mode in('head_to_head','head_to_head_percentage','mini_table')then
 select min(meetings),max(meetings)into small,large from(select a,b,(select count(*)from boss_private.ranking_sides(results)s where s.entry=a and s.opponent=b)meetings from unnest(cohort)a cross join unnest(cohort)b where a<>b)p;
 if small<needed or small<>large then return null;end if;opponents:=cohort;
 elsif mode='common_opponents'then
 select array_agg(opponent order by opponent)into opponents from(select s.opponent from boss_private.ranking_sides(results)s where s.entry=any(cohort)and not s.opponent=any(cohort)group by s.opponent having count(distinct s.entry)=cardinality(cohort))q;
 if coalesce(cardinality(opponents),0)=0 then return null;end if;
 select min(meetings),max(meetings)into small,large from(select a,b,(select count(*)from boss_private.ranking_sides(results)s where s.entry=a and s.opponent=b)meetings from unnest(cohort)a cross join unnest(opponents)b)p;
 if small<needed or small<>large then return null;end if;
 elsif mode in('conference_percentage','division_percentage')then
 if not rule?'group_id'then return null;end if;
 select(sum(case s.outcome when'win'then 1 when'tie'then(policy->>'tie_weight')::numeric else 0 end)/nullif(count(*),0))into answer from boss_private.ranking_sides(results)s where s.entry=id and s.groups? (rule->>'group_id');return answer;
 elsif mode in('differential','capped_differential','allowed','scoring_for','set_percentage','point_ratio')then
 if exists(select 1 from boss_private.ranking_sides(results)s where s.entry=id and(case when mode='point_ratio'then s.point_for is null or s.point_against is null else s.pf is null or s.pa is null end))then return null;end if;
 select case mode when'differential'then sum(s.pf-s.pa)when'capped_differential'then sum(greatest(-(rule->>'cap')::numeric,least((rule->>'cap')::numeric,s.pf-s.pa)))when'allowed'then -sum(s.pa)when'scoring_for'then sum(s.pf)when'set_percentage'then sum(s.pf)/nullif(sum(s.pf+s.pa),0)when'point_ratio'then sum(s.point_for)/nullif(sum(s.point_against),0)end into answer from boss_private.ranking_sides(results)s where s.entry=id;return answer;
 elsif mode='administrative'then return(candidate->'metrics'->>'administrative')::numeric;
 else return null; -- Strength of schedule is a foundation, not an invented formula.
 end if;
 select case when mode='mini_table'and policy->>'order_by'='points'then sum(case s.outcome when'win'then(policy->>'win_points')::numeric when'tie'then(policy->>'tie_points')::numeric else(policy->>'loss_points')::numeric end)
 when mode='head_to_head'then sum(case s.outcome when'win'then 1 when'tie'then(policy->>'tie_weight')::numeric else 0 end)
 else sum(case s.outcome when'win'then 1 when'tie'then(policy->>'tie_weight')::numeric else 0 end)/nullif(count(*),0)end into answer from boss_private.ranking_sides(results)s where s.entry=id and s.opponent=any(opponents);return answer;
end$$;
-- Recursively partition whole tied cohorts. Never use a non-transitive pairwise comparator.
create function boss_private.ranking_resolve_cohort(rows jsonb,results jsonb,policy jsonb,criterion integer,first_rank integer,trace jsonb default'[]')returns jsonb
language plpgsql immutable set search_path=''as $$
declare ids text[];rule jsonb;values jsonb;step jsonb;part record;part_rows jsonb;answer jsonb:='[]';offset_rank int:=first_rank;next_rule int;begin
 select array_agg(r->>'entry_id'order by r->>'entry_id')into ids from jsonb_array_elements(rows)r;
 if jsonb_array_length(rows)=1 or criterion>=jsonb_array_length(coalesce(policy->'tiebreaks','[]'))then
 return(select coalesce(jsonb_agg(r||jsonb_build_object('rank',first_rank,'explanation',jsonb_build_object('initial',r->'metrics','cohort',to_jsonb(ids),'steps',trace,'state',case when cardinality(ids)>1 then'unresolved_tie'else'resolved'end))order by r->>'entry_id'),'[]')from jsonb_array_elements(rows)r);end if;
 rule:=policy->'tiebreaks'->criterion;
 select jsonb_agg(jsonb_build_object('entry_id',r->>'entry_id','value',boss_private.ranking_tiebreak_value(r,ids,results,rule,policy))order by r->>'entry_id')into values from jsonb_array_elements(rows)r;
 step:=jsonb_build_object('cohort',to_jsonb(ids),'rule',rule,'values',values,'applicable',not exists(select 1 from jsonb_array_elements(values)v where v->>'value'is null));
 if exists(select 1 from jsonb_array_elements(values)v where v->>'value'is null)or(select count(distinct(v->>'value')::numeric)from jsonb_array_elements(values)v)=1 then
 return boss_private.ranking_resolve_cohort(rows,results,policy,criterion+1,first_rank,trace||jsonb_build_array(step||jsonb_build_object('result','remaining_tied')));end if;
 for part in select(v->>'value')::numeric value,jsonb_agg(v->>'entry_id')ids from jsonb_array_elements(values)v group by(v->>'value')::numeric order by(v->>'value')::numeric desc loop
 select jsonb_agg(r order by r->>'entry_id')into part_rows from jsonb_array_elements(rows)r where part.ids? (r->>'entry_id');
 next_rule:=case when rule->>'type'='mini_table'and coalesce((policy->>'mini_table_restart')::boolean,false)then 0 else criterion+1 end;
 answer:=answer||boss_private.ranking_resolve_cohort(part_rows,results,policy,next_rule,offset_rank,trace||jsonb_build_array(step||jsonb_build_object('result','partitioned','remaining_cohort',part.ids)));
 offset_rank:=offset_rank+jsonb_array_length(part_rows);end loop;return answer;
end$$;
create function boss_private.ranking_standings_build(scope public.ranking_scopes)returns void language plpgsql security definer set search_path=''as $$
declare policy jsonb;results jsonb;rows jsonb;ranked jsonb:='[]';part record;offset_rank int:=1;begin
 select coalesce(p.configuration,'{}')into policy from public.competition_editions e left join public.standings_policy_revisions p on p.id=e.standings_policy_id where e.id=scope.edition_id;
 results:=boss_private.ranking_results(scope.edition_id);
 if scope.group_id is not null then select coalesce(jsonb_agg(r),'[]')into results from jsonb_array_elements(results)r where r->'group_ids'?scope.group_id::text;end if;
 with entries as(select ce.*from public.competition_entries ce where ce.edition_id=scope.edition_id and ce.status='active'and ce.entered_at<=clock_timestamp()and(ce.ended_at is null or ce.ended_at>clock_timestamp())and(scope.group_id is null or exists(select 1 from public.competition_entry_groups eg where eg.entry_id=ce.id and eg.group_id=scope.group_id and eg.status='active'and eg.starts_at<=clock_timestamp()and(eg.ends_at is null or eg.ends_at>clock_timestamp())))and not exists(select 1 from boss_private.ranking_active_rulings(scope.edition_id)r where r.kind='eligibility'and r.primary_entry_id=ce.id and r.amount=0)),
 totals as(select e.id,
 count(*)filter(where s.outcome='win')::numeric+coalesce((select sum(r.amount)from boss_private.ranking_active_rulings(scope.edition_id)r where r.primary_entry_id=e.id and r.kind='win_adjustment'and(r.group_id is null or r.group_id=scope.group_id)),0)wins,
 count(*)filter(where s.outcome='loss')::numeric+coalesce((select sum(r.amount)from boss_private.ranking_active_rulings(scope.edition_id)r where r.primary_entry_id=e.id and r.kind='loss_adjustment'and(r.group_id is null or r.group_id=scope.group_id)),0)losses,
 count(*)filter(where s.outcome='tie')::numeric ties,count(s.entry)::numeric gp,
 case when count(*)filter(where s.entry is not null and s.pf is null)=0 then sum(s.pf)end pf,case when count(*)filter(where s.entry is not null and s.pa is null)=0 then sum(s.pa)end pa,
 case when count(*)filter(where s.entry is not null and(s.point_for is null or s.point_against is null))=0 then sum(s.point_for)/nullif(sum(s.point_against),0)end point_ratio,
 (select r.amount from boss_private.ranking_active_rulings(scope.edition_id)r where r.primary_entry_id=e.id and r.kind='tie_resolution'and r.group_id is not distinct from scope.group_id order by r.effective_at desc,r.created_at desc,r.id desc limit 1)administrative,
 coalesce((select sum(r.amount)from boss_private.ranking_active_rulings(scope.edition_id)r where r.primary_entry_id=e.id and r.kind='points_adjustment'and(r.group_id is null or r.group_id=scope.group_id)),0)points_adjustment
 from entries e left join boss_private.ranking_sides(results)s on s.entry=e.id::text group by e.id),
 metrics as(select t.*,case when policy?'order_by'then(wins+ties*(policy->>'tie_weight')::numeric)/nullif(gp,0)end pct,
 case when policy?'win_points'then wins*(policy->>'win_points')::numeric+ties*(policy->>'tie_points')::numeric+losses*(policy->>'loss_points')::numeric+points_adjustment end points from totals t)
 select coalesce(jsonb_agg(jsonb_build_object('entry_id',id,'metrics',to_jsonb(m),'base',case policy->>'order_by'when'wins'then wins when'points'then points when'win_percentage'then pct else null end)order by id),'[]')into rows from metrics m;
 for part in select(r->>'base')::numeric base,jsonb_agg(r order by r->>'entry_id')cohort from jsonb_array_elements(rows)r group by(r->>'base')::numeric order by(r->>'base')::numeric desc nulls last loop
 ranked:=ranked||boss_private.ranking_resolve_cohort(part.cohort,results,policy,0,offset_rank);offset_rank:=offset_rank+jsonb_array_length(part.cohort);end loop;
 delete from public.standings_rows where scope_id=scope.id;
 insert into public.standings_rows(scope_id,entry_id,rank,wins,losses,ties,games_played,points,win_percentage,scoring_for,scoring_against,metrics,explanation)
 select scope.id,(r->>'entry_id')::uuid,(r->>'rank')::int,(r->'metrics'->>'wins')::numeric,(r->'metrics'->>'losses')::numeric,(r->'metrics'->>'ties')::numeric,(r->'metrics'->>'gp')::numeric,(r->'metrics'->>'points')::numeric,(r->'metrics'->>'pct')::numeric,(r->'metrics'->>'pf')::numeric,(r->'metrics'->>'pa')::numeric,r->'metrics',r->'explanation'from jsonb_array_elements(ranked)r;
end$$;
-- A dependency vector includes dirty and newly eligible games, not only the previously selected members.
create function boss_private.ranking_source_games(scope public.ranking_scopes)returns table(game_id uuid)language sql stable security definer set search_path=''as $$
 select a.game_id from boss_private.ranking_latest_assignments(scope.edition_id)a where scope.product='standings'and a.status='active'and a.counts_for_standings
 union select g.id from public.ranking_definitions d join public.competition_editions e on e.id=d.edition_id join public.games g on g.organization_id=d.source_organization_id and g.sport_key=e.sport_key and(d.team_id is null or d.team_id in(g.primary_team_id,g.opponent_team_id))and(d.season_id is null or d.season_id=g.season_id)
 where d.id=scope.definition_id and(not d.competition_only or exists(select 1 from boss_private.ranking_latest_assignments(e.id)a where a.game_id=g.id and a.status='active'and a.counts_for_standings))
$$;
create function boss_private.ranking_source_manifest(scope public.ranking_scopes)returns jsonb language sql stable security definer set search_path=''as $$
 select jsonb_build_object('definition_version','intelligence-v1','edition_generation',e.generation,'policy_id',e.standings_policy_id,'definition',case when d.id is null then null else to_jsonb(d)-array['name','actor_person_id']end,
 'sources',coalesce((select jsonb_agg(jsonb_build_object('game_id',g.id,'status',g.status,'epoch',g.finalization_count,'generation',gs.generation,'refreshed_generation',gs.refreshed_generation,'finalization_id',gs.finalization_id)order by g.id)from boss_private.ranking_source_games(scope)src join public.games g on g.id=src.game_id left join public.stat_game_selections gs on gs.game_id=g.id),'[]'),
 'assignments',coalesce((select jsonb_agg(a.id order by a.id)from boss_private.ranking_latest_assignments(e.id)a),'[]'),
 'entries',coalesce((select jsonb_agg(jsonb_build_array(ce.id,ce.version,ce.status,ce.entered_at,ce.ended_at)order by ce.id)from public.competition_entries ce where ce.edition_id=e.id),'[]'),
 'groups',coalesce((select jsonb_agg(jsonb_build_array(eg.id,eg.status,eg.starts_at,eg.ends_at)order by eg.id)from public.competition_entry_groups eg where eg.edition_id=e.id),'[]'),
 'rulings',coalesce((select jsonb_agg(r.id order by r.id)from boss_private.ranking_active_rulings(e.id)r),'[]'))
 from public.competition_editions e left join public.ranking_definitions d on d.id=scope.definition_id where e.id=scope.edition_id
$$;
create function boss_private.ranking_next_boundary(edition uuid)returns timestamptz language sql volatile security definer set search_path=''as $$
 select min(t)from(select starts_at t from public.competition_editions where id=edition union all select ends_at from public.competition_editions where id=edition union all select entered_at from public.competition_entries where edition_id=edition union all select ended_at from public.competition_entries where edition_id=edition union all select starts_at from public.competition_entry_groups where edition_id=edition union all select ends_at from public.competition_entry_groups where edition_id=edition union all select effective_at from public.competition_rulings where edition_id=edition)boundaries where t>clock_timestamp()
$$;
create function boss_private.ranking_pool(definition uuid,p_group uuid default null)returns table(subject_key text,team_id uuid,game_id uuid)language sql stable security definer set search_path=''as $$
 select case d.source_kind when'athlete_game'then c.person_id::text||':'||c.game_id::text when'team_game'then c.team_id::text||':'||c.game_id::text when'team_season'then c.team_id::text else c.person_id::text end,c.team_id,c.game_id
 from public.ranking_definitions d join public.competition_editions e on e.id=d.edition_id
 join public.stat_game_contributions c on c.organization_id=d.source_organization_id and c.sport_key=e.sport_key and(d.team_id is null or c.team_id=d.team_id)and(d.season_id is null or c.season_id=d.season_id)and c.classification='official'and c.definition_version=d.stat_definition_version
 join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id and gs.refreshed_generation=gs.generation
 join public.games g on g.id=c.game_id and g.status='final'and g.finalization_count=c.epoch
 join public.game_finalizations f on f.id=c.finalization_id
 where d.id=definition and((d.source_kind like'team_%'and c.person_id is null)or(d.source_kind not like'team_%'and c.person_id is not null))
 and(p_group is null or exists(select 1 from public.competition_entries ce join public.competition_entry_groups eg on eg.entry_id=ce.id where ce.edition_id=e.id and ce.team_id=c.team_id and ce.status='active'and ce.entered_at<=clock_timestamp()and(ce.ended_at is null or ce.ended_at>clock_timestamp())and eg.group_id=p_group and eg.status='active'and eg.starts_at<=clock_timestamp()and(eg.ends_at is null or eg.ends_at>clock_timestamp())))
 and(not d.competition_only or exists(select 1 from boss_private.ranking_latest_assignments(e.id)a where a.game_id=c.game_id and a.status='active'and a.counts_for_standings and(p_group is null or exists(select 1 from public.competition_game_assignment_groups ag where ag.assignment_id=a.id and ag.group_id=p_group))and c.team_id in((select team_id from public.competition_entries where id=a.primary_entry_id),(select team_id from public.competition_entries where id=a.opponent_entry_id))))
$$;
create function boss_private.ranking_contributions(definition uuid,p_group uuid default null,p_subjects text[]default null)returns table(subject_key text,payload jsonb,performance_at timestamptz)
language sql stable security definer set search_path=''as $$
 select case d.source_kind when'athlete_game'then c.person_id::text||':'||c.game_id::text when'team_game'then c.team_id::text||':'||c.game_id::text when'team_season'then c.team_id::text else c.person_id::text end,
 to_jsonb(c)||jsonb_build_object('source_generation',gs.generation,'performance_at',case when f.epoch>1 then greatest(coalesce(g.started_at,g.scheduled_start_at),f.created_at)else coalesce(g.started_at,g.scheduled_start_at) end),
 case when f.epoch>1 then greatest(coalesce(g.started_at,g.scheduled_start_at),f.created_at)else coalesce(g.started_at,g.scheduled_start_at) end
 from public.ranking_definitions d join public.competition_editions e on e.id=d.edition_id
 join public.stat_game_contributions c on c.organization_id=d.source_organization_id and c.sport_key=e.sport_key and(d.team_id is null or c.team_id=d.team_id)and(d.season_id is null or c.season_id=d.season_id)and c.classification='official'and c.definition_version=d.stat_definition_version
 join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id and gs.refreshed_generation=gs.generation
 join public.games g on g.id=c.game_id and g.status='final'and g.finalization_count=c.epoch
 join public.game_finalizations f on f.id=c.finalization_id
 where d.id=definition and(p_subjects is null or case d.source_kind when'athlete_game'then c.person_id::text||':'||c.game_id::text when'team_game'then c.team_id::text||':'||c.game_id::text when'team_season'then c.team_id::text else c.person_id::text end=any(p_subjects))and((d.source_kind like'team_%'and c.person_id is null)or(d.source_kind not like'team_%'and c.person_id is not null))
 and(p_group is null or exists(select 1 from public.competition_entries ce join public.competition_entry_groups eg on eg.entry_id=ce.id where ce.edition_id=e.id and ce.team_id=c.team_id and ce.status='active'and ce.entered_at<=clock_timestamp()and(ce.ended_at is null or ce.ended_at>clock_timestamp())and eg.group_id=p_group and eg.status='active'and eg.starts_at<=clock_timestamp()and(eg.ends_at is null or eg.ends_at>clock_timestamp())))
 and(not d.competition_only or exists(select 1 from boss_private.ranking_latest_assignments(e.id)a where a.game_id=c.game_id and a.status='active'and a.counts_for_standings and(p_group is null or exists(select 1 from public.competition_game_assignment_groups ag where ag.assignment_id=a.id and ag.group_id=p_group))and c.team_id in((select team_id from public.competition_entries where id=a.primary_entry_id),(select team_id from public.competition_entries where id=a.opponent_entry_id))))
$$;
create function boss_private.ranking_candidate_measure(d public.ranking_definitions,rows jsonb,team_games int)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare result jsonb;prefix jsonb:='[]';r jsonb;measure jsonb;measured_rows jsonb;achieved timestamptz;sport text;lo int;hi int;mid int;threshold_keys text[];monotone boolean;begin
 select sport_key into sport from public.competition_editions where id=d.edition_id;
 select coalesce(jsonb_agg(measured),'[]')into measured_rows from jsonb_array_elements(rows)measured where d.source_kind like'team_%'or coalesce((measured->'participation'->>'confirmed')::boolean,false);
 result:=boss_private.ranking_measure(sport,measured_rows,d.metric_key,d.metric_kind,d.qualification,d.allow_partial,team_games);
 -- Source chronology, never recognition wall-clock time or an average of game rates.
 select coalesce(jsonb_agg(value order by(value->>'performance_at')::timestamptz,value->>'game_id',value->>'id'),'[]')into measured_rows from jsonb_array_elements(measured_rows);
 threshold_keys:=array[d.metric_key]||array(select boss_private.ranking_threshold_metric(t)from jsonb_array_elements(coalesce(d.qualification->'thresholds','[]'))t where boss_private.ranking_threshold_metric(t)is not null);
 monotone:=d.metric_kind='count'and not exists(select 1 from jsonb_array_elements(measured_rows)x cross join unnest(threshold_keys)k where jsonb_typeof(x->'components'->k)='number'and(x->'components'->>k)::numeric<0);
 if result->>'state'='qualified'and monotone then
 -- Nonnegative counting totals and explicit minima are monotone for this fixed
 -- canonical cohort. Binary search still evaluates the SAME Phase 6A reducer.
 lo:=1;hi:=jsonb_array_length(measured_rows);
 while lo<hi loop mid:=(lo+hi)/2;
 select jsonb_agg(value order by ordinal)into prefix from jsonb_array_elements(measured_rows)with ordinality x(value,ordinal)where ordinal<=mid;
 measure:=boss_private.ranking_measure(sport,prefix,d.metric_key,d.metric_kind,d.qualification,d.allow_partial,team_games);
 if measure->>'state'='qualified'and(measure->>'value')::numeric=(result->>'value')::numeric then hi:=mid;else lo:=mid+1;end if;end loop;
 achieved:=(measured_rows->(lo-1)->>'performance_at')::timestamptz;
 elsif result->>'state'='qualified'then
 for r in select value from jsonb_array_elements(measured_rows)loop
 prefix:=prefix||jsonb_build_array(r);
 measure:=boss_private.ranking_measure(sport,prefix,d.metric_key,d.metric_kind,d.qualification,d.allow_partial,team_games);
 if measure->>'state'='qualified'and(measure->>'value')::numeric=(result->>'value')::numeric then achieved:=(r->>'performance_at')::timestamptz;exit;end if;end loop;
 end if;
 return result||jsonb_build_object('achieved_at',achieved,'source_manifest',jsonb_build_object('definition_id',d.id,'definition_version',d.version,'stat_definition_version',d.stat_definition_version,'source_kind',d.source_kind,'sport_key',sport,'organization_id',d.source_organization_id,'team_id',d.team_id,'season_id',d.season_id,'team_games',team_games,'qualification',d.qualification,'partial_basis',d.allow_partial,
 'sources',(select coalesce(jsonb_agg(jsonb_build_object('contribution_id',x->'id','game_id',x->'game_id','finalization_id',x->'finalization_id','epoch',x->'epoch','source_generation',x->'source_generation','classification_id',x->'classification_id','person_id',x->'person_id','participant_id',x->'participant_id','team_id',x->'team_id','season_id',x->'season_id','performance_at',x->'performance_at','era_basis_innings',x->'era_basis_innings')order by x->>'game_id',x->>'id'),'[]')from jsonb_array_elements(rows)x)));
end$$;
create function boss_private.ranking_record_event(d uuid,subject text,event_type text,v numeric,achieved timestamptz,manifest jsonb,q jsonb,gen bigint,previous uuid,p_scope uuid)returns uuid
language plpgsql security definer set search_path=''as $$
declare event_id uuid;key text:=md5(jsonb_build_array(p_scope,d,subject,event_type,v,achieved,manifest,q,previous)::text);begin
 insert into public.record_events(scope_id,definition_id,subject_key,event_key,event_type,value,achieved_at,source_manifest,qualification,generation,previous_event_id)
 values(p_scope,d,subject,key,event_type,v,achieved,manifest,q,gen,previous)on conflict(event_key)do nothing returning id into event_id;
 if event_id is null then select id into event_id from public.record_events where event_key=key;end if;return event_id;
end$$;
create function boss_private.ranking_records_publish(scope public.ranking_scopes,d public.ranking_definitions)returns void language plpgsql security definer set search_path=''as $$
declare old record;c public.ranking_candidates;prior public.record_events;new_event uuid;disposition text;holder_count int:=0;begin
 -- Old recognition payload stays immutable while candidates are rebuilt in place.
 for old in select h.*,ev.value,ev.achieved_at,ev.source_manifest,ev.qualification,ev.id recognition_id from public.record_current_holders h join public.record_events ev on ev.id=h.event_id where h.scope_id=scope.id order by h.subject_key loop
 select *into c from public.ranking_candidates where scope_id=scope.id and subject_key=old.subject_key and built_generation=scope.target_generation;
 if c.id is not null and c.rank=1 and c.qualification_state='qualified'and c.value=old.value and c.source_manifest=old.source_manifest then holder_count:=holder_count+1;continue;end if;
 disposition:=case when c.id is null or c.qualification_state<>'qualified'or(c.value is distinct from old.value and not exists(select 1 from jsonb_array_elements(c.source_manifest->'sources')n where not exists(select 1 from jsonb_array_elements(old.source_manifest->'sources')p where n->>'game_id'=p->>'game_id')))or exists(select 1 from jsonb_array_elements(old.source_manifest->'sources')p where not exists(select 1 from jsonb_array_elements(c.source_manifest->'sources')n where n->>'game_id'=p->>'game_id'and n->>'finalization_id'=p->>'finalization_id'))then'invalidated_by_source_correction'else'superseded'end;
 perform boss_private.ranking_record_event(d.id,old.subject_key,disposition,old.value,old.achieved_at,old.source_manifest,old.qualification,scope.target_generation,old.recognition_id,scope.id);
 delete from public.record_current_holders where scope_id=scope.id and subject_key=old.subject_key;
 end loop;
 for c in select *from public.ranking_candidates where scope_id=scope.id and built_generation=scope.target_generation and qualification_state='qualified'and rank=1 order by achieved_at,subject_key loop
 if exists(select 1 from public.record_current_holders where scope_id=scope.id and subject_key=c.subject_key)then continue;end if;
 select *into prior from public.record_events where scope_id=scope.id and subject_key=c.subject_key order by recognized_at desc,id desc limit 1;
 disposition:=case when exists(select 1 from public.record_events previous_recognition where previous_recognition.scope_id=scope.id and previous_recognition.subject_key=c.subject_key and previous_recognition.event_type in('recognized','co_holder_added','restored')and previous_recognition.value=c.value and previous_recognition.achieved_at=c.achieved_at)then'restored'when holder_count>0 then'co_holder_added'else'recognized'end;
 new_event:=boss_private.ranking_record_event(d.id,c.subject_key,disposition,c.value,c.achieved_at,c.source_manifest,c.qualification,scope.target_generation,prior.id,scope.id);
 insert into public.record_current_holders(scope_id,definition_id,subject_key,event_id,candidate_id)values(scope.id,d.id,c.subject_key,new_event,c.id);
 holder_count:=holder_count+1;
 end loop;
end$$;
create function boss_private.ranking_candidates_batch(scope public.ranking_scopes)returns boolean language plpgsql security definer set search_path=''as $$
declare d public.ranking_definitions;subject record;rows jsonb;measure jsonb;games int;processed int:=0;last_key text;selected_keys text[];begin
 select *into d from public.ranking_definitions where id=scope.definition_id;
 -- Key selection never serializes the whole pool. Only this batch carries JSON.
 select coalesce(array_agg(subject_key order by subject_key),'{}')into selected_keys from(select distinct src.subject_key from boss_private.ranking_pool(d.id,scope.group_id)src where scope.build_cursor is null or src.subject_key>scope.build_cursor order by src.subject_key limit 100)keys;
 for subject in with sources as materialized(select *from boss_private.ranking_contributions(d.id,scope.group_id,selected_keys)),
 team_games as materialized(select src.team_id::text team,array_agg(distinct src.game_id::text)games from boss_private.ranking_pool(d.id,scope.group_id)src where src.team_id::text in(select distinct payload->>'team_id'from sources)group by src.team_id),
 selected as(select distinct subject_key from sources where scope.build_cursor is null or subject_key>scope.build_cursor order by subject_key limit 100),
 grouped as(select src.subject_key,jsonb_agg(src.payload order by src.performance_at,src.payload->>'game_id',src.payload->>'id') rows from sources src join selected x using(subject_key)group by src.subject_key)
 select grouped.*,(select count(distinct game_id)from team_games cross join lateral unnest(team_games.games)game_id where team_games.team in(select distinct r->>'team_id'from jsonb_array_elements(grouped.rows)r))::int games from grouped order by subject_key loop
 rows:=subject.rows;games:=subject.games;
 -- This measure uses the existing Phase 6A reducers, including joint-rate and ERA rules.
 measure:=boss_private.ranking_candidate_measure(d,rows,games);
 insert into public.ranking_candidates(scope_id,subject_key,person_id,team_id,built_generation,value,qualification_state,qualification,coverage,summary,source_manifest,achieved_at)
 values(scope.id,subject.subject_key,(rows->0->>'person_id')::uuid,case when d.team_id is not null or d.source_kind like'team_%'then(rows->0->>'team_id')::uuid end,scope.target_generation,(measure->>'value')::numeric,measure->>'state',jsonb_build_object('thresholds',measure->'thresholds','basis',d.qualification),measure->'coverage',measure->'summary',(measure->'source_manifest')||jsonb_build_object('scope_id',scope.id,'group_id',scope.group_id,'edition_id',scope.edition_id),(measure->>'achieved_at')::timestamptz)
 on conflict(scope_id,subject_key)do update set person_id=excluded.person_id,team_id=excluded.team_id,built_generation=excluded.built_generation,value=excluded.value,rank=null,qualification_state=excluded.qualification_state,qualification=excluded.qualification,coverage=excluded.coverage,summary=excluded.summary,source_manifest=excluded.source_manifest,achieved_at=excluded.achieved_at;
 processed:=processed+1;last_key:=subject.subject_key;
 end loop;
 if processed=100 and exists(select 1 from boss_private.ranking_pool(d.id,scope.group_id)src where src.subject_key>last_key)then update public.ranking_scopes set build_cursor=last_key,state='refreshing',reason='candidate_batch_pending'where id=scope.id;return false;end if;
 with ranks as materialized(select id,rank()over(order by case when d.direction='high'then value else-value end desc)::int ranking from public.ranking_candidates where scope_id=scope.id and built_generation=scope.target_generation and qualification_state='qualified')update public.ranking_candidates c set rank=r.ranking from ranks r where r.id=c.id;
 if d.product='records'then perform boss_private.ranking_records_publish(scope,d);end if;
 delete from public.ranking_candidates where scope_id=scope.id and built_generation<>scope.target_generation;
 return true;
end$$;
create function boss_private.ranking_refresh(p_scope uuid,p_actor uuid default null)returns boolean language plpgsql volatile security definer set search_path=''as $$
declare scope public.ranking_scopes;e public.competition_editions;src record;manifest jsonb;next_boundary timestamptz;complete boolean;begin
 select *into scope from public.ranking_scopes where id=p_scope;
 if scope.id is null then raise exception 'Ranking unavailable'using errcode='PT403';end if;
 -- Bounded source repair before any edition/ranking fence, preserving canonical lock order.
 for src in select sg.game_id from boss_private.ranking_source_games(scope)sg left join public.stat_game_selections gs on gs.game_id=sg.game_id where gs.game_id is null or gs.generation<>gs.refreshed_generation order by sg.game_id limit 8 loop
 if not boss_private.stat_refresh(src.game_id)then return false;end if;end loop;
 if exists(select 1 from boss_private.ranking_source_games(scope)sg left join public.stat_game_selections gs on gs.game_id=sg.game_id where gs.game_id is null or gs.generation<>gs.refreshed_generation)then return false;end if;
 -- No canonical source lock is acquired below this fence.
 if p_actor is not null then perform boss_private.ranking_lock_authority(p_actor,scope.edition_id);end if;
 set constraints public.ranking_stat_source_changed immediate;
 set constraints public.ranking_stat_source_changed deferred;
 select *into e from public.competition_editions where id=scope.edition_id for update;
 select *into scope from public.ranking_scopes where id=p_scope for update;
 if scope.target_generation<>e.generation then update public.ranking_scopes set target_generation=e.generation,state='pending',build_cursor=null where id=p_scope returning *into scope;end if;
 if scope.valid_until is not null and scope.valid_until<=clock_timestamp()then
 perform boss_private.ranking_dirty_edition(e.id);select *into scope from public.ranking_scopes where id=p_scope;
 end if;
 manifest:=boss_private.ranking_source_manifest(scope);
 if scope.state='current'and scope.published_generation=scope.target_generation and scope.source_hash=md5(manifest::text)then return true;end if;
 -- Recheck after waiting for the edition lock; dirty work cannot publish a partial vector.
 if exists(select 1 from boss_private.ranking_source_games(scope)sg left join public.stat_game_selections gs on gs.game_id=sg.game_id where gs.game_id is null or gs.generation<>gs.refreshed_generation)then update public.ranking_scopes set state='pending',reason='source_pending'where id=p_scope;return false;end if;
 if scope.product='standings'then perform boss_private.ranking_standings_build(scope);complete:=true;else complete:=boss_private.ranking_candidates_batch(scope);end if;
 if not complete then return false;end if;
 next_boundary:=boss_private.ranking_next_boundary(scope.edition_id);
 update public.ranking_scopes set published_generation=target_generation,source_manifest=manifest,source_hash=md5(manifest::text),refreshed_at=clock_timestamp(),valid_until=next_boundary,state='current',reason=null,build_cursor=null where id=p_scope;
 delete from public.ranking_refresh_work where scope_id=p_scope and target_generation=scope.target_generation;return true;
end$$;
do $$declare f record;begin
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'ranking_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.sig);end loop;
end$$;
