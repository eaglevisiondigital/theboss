-- Synthetic, disposable Phase 6E fixture only.
\ir ../phase6d/fixture.sql
select boss_private.stat_refresh(g.id)from public.games g join public.stat_game_selections s on s.game_id=g.id where g.organization_id=pg_temp.f('org')and g.sport_key='baseball'and s.generation<>s.refreshed_generation order by g.id;
create temp table phase6e_ids(label text primary key,id uuid not null)on commit drop;
grant select,insert,update on phase6e_ids to authenticated;
create function pg_temp.pe_id(k text)returns uuid language sql stable as $$select id from pg_temp.phase6e_ids where label=k$$;
create function pg_temp.pe(action text,input jsonb,p_label text default null,request uuid default null)returns jsonb language plpgsql as $$declare result jsonb;begin result:=public.boss_achievement_mutate(jsonb_build_object('action',action,'request_id',coalesce(request,gen_random_uuid()),'input',input));if p_label is not null then insert into pg_temp.phase6e_ids values(p_label,(result->>'id')::uuid)on conflict(label)do update set id=excluded.id;end if;return result;end$$;
create function pg_temp.pe_rule(k text,extra jsonb default'{}')returns jsonb language sql stable as $$select jsonb_build_object('name','Synthetic '||k,'subject_type','athlete','category','statistical_milestone','source_kind','athlete_career','sport_key','baseball','team_id',pg_temp.f('falcons'),'metric_key','home_runs','threshold',1,'historical_evaluation',true,'showcase_eligible',true)||extra$$;
create function pg_temp.pe_definition(k text,rule jsonb)returns jsonb language sql as $$select pg_temp.pe('definition.create',jsonb_build_object('organization_id',pg_temp.f('org'),'owner_kind','organization','definition_key',k,'revision',rule),k)$$;
create function pg_temp.pe_evaluate(k text,rebuild boolean default false)returns jsonb language plpgsql as $$declare result jsonb;n int:=0;begin loop result:=pg_temp.pe(case when rebuild and n=0 then'definition.rebuild'else'definition.evaluate'end,jsonb_build_object('definition_id',pg_temp.pe_id(k)));n:=n+1;exit when result->>'has_more'<>'true';if n>30 then raise exception'Bounded test evaluation did not complete';end if;end loop;return result;end$$;
revoke all on function pg_temp.pe_id(text),pg_temp.pe(text,jsonb,text,uuid),pg_temp.pe_rule(text,jsonb),pg_temp.pe_definition(text,jsonb),pg_temp.pe_evaluate(text,boolean)from public;
grant execute on function pg_temp.pe_id(text),pg_temp.pe(text,jsonb,text,uuid),pg_temp.pe_rule(text,jsonb),pg_temp.pe_definition(text,jsonb),pg_temp.pe_evaluate(text,boolean)to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select(public.boss_athlete_profile_mutate(jsonb_build_object('action','profile.create','request_id',gen_random_uuid(),'input',jsonb_build_object('participant_id',pg_temp.f('participant-child1'),'visibility','athlete_guardian','safe_fields',jsonb_build_object('display_name','Synthetic Child One'))))->>'profile_id')::uuid pe_profile \gset
insert into pg_temp.phase6e_ids values('profile',:'pe_profile');
select pg_temp.pe_definition('career_one',pg_temp.pe_rule('career_one'));
select pg_temp.pe_evaluate('career_one');
select pg_temp.pe_definition('manual_mvp',jsonb_build_object('name','Synthetic MVP','subject_type','athlete','category','mvp','source_kind','organization_decision','sport_key','baseball','team_id',pg_temp.f('falcons'),'season_id',pg_temp.f('season'),'historical_evaluation',true,'showcase_eligible',true,'approval_required',true));
reset role;
