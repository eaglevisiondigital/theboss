-- Disposable synthetic identities only. No hosted grants or real personal data.
\ir ../phase5f/fixture.sql
create temp table phase6b_ids(label text primary key,id uuid not null)on commit drop;
grant select,insert,update on phase6b_ids to authenticated;
create function pg_temp.rb_id(k text)returns uuid language sql stable as $$select id from pg_temp.phase6b_ids where label=k$$;
create function pg_temp.rb(action text,input jsonb,p_label text default null,request uuid default null)returns jsonb language plpgsql as $$declare r jsonb;begin
 r:=public.boss_ranking_mutate(jsonb_build_object('action',action,'request_id',coalesce(request,gen_random_uuid()),'input',input));
 if p_label is not null then insert into pg_temp.phase6b_ids values(p_label,(r->>'id')::uuid)on conflict(label)do update set id=excluded.id;end if;return r;end$$;
create function pg_temp.rb_q(product text default'standings',definition text default null,extra jsonb default'{}')returns jsonb language sql stable as $$select jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'product',product)||case when definition is null then'{}'::jsonb else jsonb_build_object('definition_id',pg_temp.rb_id(definition))end||extra$$;
create function pg_temp.rb_policy(sport text default'baseball',order_by text default'win_percentage',rules jsonb default'[]')returns jsonb language sql immutable as $$select jsonb_build_object('template',sport,'order_by',order_by,'tie_weight',0.5,'allow_ties',true,'win_points',3,'tie_points',1,'loss_points',0,'tiebreaks',rules,'allow_manual_resolution',false,'mini_table_restart',false)$$;
revoke all on function pg_temp.rb_id(text),pg_temp.rb(text,jsonb,text,uuid),pg_temp.rb_q(text,text,jsonb),pg_temp.rb_policy(text,text,jsonb)from public;
grant execute on function pg_temp.rb_id(text),pg_temp.rb(text,jsonb,text,uuid),pg_temp.rb_q(text,text,jsonb),pg_temp.rb_policy(text,text,jsonb)to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('competition.create',jsonb_build_object('organization_id',pg_temp.f('org'),'name','Synthetic Phase 6B Competition'),'competition');
select pg_temp.rb('edition.create',jsonb_build_object('competition_id',pg_temp.rb_id('competition'),'sport_key','baseball','season_id',pg_temp.f('season'),'name','Synthetic Phase 6B Edition','team_result_audience','entry_teams'),'edition');
select pg_temp.rb('entry.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'team_id',pg_temp.f('falcons')),'falcons-entry');
select pg_temp.rb('entry.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'team_id',pg_temp.f('wildcats')),'wildcats-entry');
select pg_temp.rb('group.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'kind','division','name','Synthetic division'),'division');
select pg_temp.rb('group.assign',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'entry_id',pg_temp.rb_id('falcons-entry'),'group_id',pg_temp.rb_id('division')),'falcons-group');
select pg_temp.rb('group.assign',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'entry_id',pg_temp.rb_id('wildcats-entry'),'group_id',pg_temp.rb_id('division')),'wildcats-group');
select pg_temp.dd_create('ranking-game','baseball','essential');
select public.boss_stat_competition_classify(pg_temp.ff_game('ranking-game'),'official','Disposable Phase 6B source',gen_random_uuid());
do $$declare half int;i int;begin
perform pg_temp.dd_pa('ranking-game','ranking-home-run');perform pg_temp.dd_play('ranking-game','home_run',jsonb_build_array(pg_temp.dd_move(0,4)));
for half in 1..2 loop for i in 1..3 loop perform pg_temp.dd_pa('ranking-game','ranking-'||half||'-'||i);perform pg_temp.dd_play('ranking-game','other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;
if half=1 then perform pg_temp.dd_op('diamond.half.start','ranking-game','{"payload":{"kind":"half_start"}}');end if;end loop;
perform pg_temp.game_op('game.finalize','ranking-game');end$$;
select pg_temp.rb('game.assign',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'game_id',pg_temp.ff_game('ranking-game'),'primary_entry_id',pg_temp.rb_id('falcons-entry'),'opponent_entry_id',pg_temp.rb_id('wildcats-entry'),'game_type','division','counts_for_standings',true,'group_ids',jsonb_build_array(pg_temp.rb_id('division')),'reason','Disposable explicit source assignment'),'assignment');
reset role;
