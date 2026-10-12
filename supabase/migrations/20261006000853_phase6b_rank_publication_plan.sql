-- Phase 6B final publication: bounded work independent of join-plan estimates.
create or replace function boss_private.ranking_candidates_batch(scope public.ranking_scopes)returns boolean language plpgsql security definer set search_path=''as $$
declare d public.ranking_definitions;subject record;rows jsonb;measure jsonb;games int;processed int:=0;last_key text;selected_keys text[];rank_map jsonb;begin
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
 -- Build one immutable rank lookup, then scan this generation once. A joined
 -- materialized rank CTE can choose quadratic nested-loop publication when
 -- a newly populated candidate table has no planner statistics yet.
 select coalesce(jsonb_object_agg(id::text,ranking),'{}')into rank_map from
 (select id,rank()over(order by case when d.direction='high'then value else-value end desc)::int ranking
 from public.ranking_candidates where scope_id=scope.id and built_generation=scope.target_generation and qualification_state='qualified')ranked;
 update public.ranking_candidates c set rank=(rank_map->>c.id::text)::int
 where c.scope_id=scope.id and c.built_generation=scope.target_generation and c.qualification_state='qualified';
 if d.product='records'then perform boss_private.ranking_records_publish(scope,d);end if;
 delete from public.ranking_candidates where scope_id=scope.id and built_generation<>scope.target_generation;
 return true;
end$$;

