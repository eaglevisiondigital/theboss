-- Synthetic disposable Phase 6D tournament fixture.
\ir ../phase6b/fixture.sql
create temp table phase6d_ids(label text primary key,id uuid not null)on commit drop;
grant select,insert,update on phase6d_ids to authenticated;
create function pg_temp.td_id(k text)returns uuid language sql stable as $$select id from pg_temp.phase6d_ids where label=k$$;
create function pg_temp.td(action text,input jsonb,p_label text default null,request uuid default null)returns jsonb language plpgsql as $$declare r jsonb;begin r:=public.boss_tournament_mutate(jsonb_build_object('action',action,'request_id',coalesce(request,gen_random_uuid()),'input',input));if p_label is not null then insert into pg_temp.phase6d_ids values(p_label,(r->>'id')::uuid)on conflict(label)do update set id=excluded.id;end if;return r;end$$;
revoke all on function pg_temp.td_id(text),pg_temp.td(text,jsonb,text,uuid)from public;grant execute on function pg_temp.td_id(text),pg_temp.td(text,jsonb,text,uuid)to authenticated;
insert into public.teams(id,organization_id,parent_unit_id,season_id,name,slug,status,visibility)values
 (pg_temp.f('hawks'),pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic Hawks','phase6d-hawks','active','member'),
 (pg_temp.f('eagles'),pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic Eagles','phase6d-eagles','active','member'),
 (pg_temp.f('bears'),pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic Bears','phase6d-bears','active','member'),
 (pg_temp.f('wolves'),pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic Wolves','phase6d-wolves','active','member');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('entry.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'team_id',pg_temp.f('hawks')),'hawks-entry');
select pg_temp.rb('entry.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'team_id',pg_temp.f('eagles')),'eagles-entry');
select pg_temp.rb('entry.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'team_id',pg_temp.f('bears')),'bears-entry');
select pg_temp.rb('entry.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'team_id',pg_temp.f('wolves')),'wolves-entry');
select pg_temp.td('bracket.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'name','Synthetic Phase 6D Bracket','bracket_size',4,'include_third_place',true),'bracket');
select pg_temp.td('bracket.seed',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('bracket'),'expected_version',1,'source_kind','manual','seeds',jsonb_build_array(
 jsonb_build_object('seed',1,'entry_id',pg_temp.rb_id('falcons-entry')),jsonb_build_object('seed',2,'entry_id',pg_temp.rb_id('hawks-entry')),
 jsonb_build_object('seed',3,'entry_id',pg_temp.rb_id('eagles-entry')),jsonb_build_object('seed',4,'entry_id',pg_temp.rb_id('wildcats-entry'))),'reason','Disposable reviewed four-team seed order'));
select pg_temp.create_game('tournament-first','neutral','falcons','baseball');
reset role;
