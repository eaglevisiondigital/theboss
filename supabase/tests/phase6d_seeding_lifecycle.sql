begin;
set local statement_timeout='8s';
\ir phase6d/fixture.sql
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
 select pg_temp.f('org'),id,'active','{"communications":true,"in_app_notifications":true,"guardian_visibility":true,"email_notifications":false}'::jsonb,now()-interval'3 days'from public.modules where key='messaging';

set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('standings',null,jsonb_build_object('group_id',pg_temp.rb_id('division'))),'phase6d-overall-scope');
reset role;
with ranked as(select entry_id,row_number()over(order by entry_id)::int resolved_rank from public.standings_rows where scope_id=pg_temp.rb_id('phase6d-overall-scope'))update public.standings_rows sr set rank=ranked.resolved_rank from ranked where sr.scope_id=pg_temp.rb_id('phase6d-overall-scope')and sr.entry_id=ranked.entry_id;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.td('bracket.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'name','Synthetic standings-seeded bracket','bracket_size',2),'standings-bracket');
select pg_temp.td('bracket.seed',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('standings-bracket'),'expected_version',1,'source_kind','standings_snapshot','source_scope_id',pg_temp.rb_id('phase6d-overall-scope'),'reason','Disposable published standings acceptance'));
reset role;

select pg_temp.check('standings snapshot preserves exact published generation','SNAPSHOT',(select count(*)=2 and min(source_generation)=max(source_generation)and min(source_generation)=(select published_generation from public.ranking_scopes where id=pg_temp.rb_id('phase6d-overall-scope'))from public.tournament_seeds where bracket_id=pg_temp.td_id('standings-bracket')));
select pg_temp.check('standings snapshot preserves source rank','SNAPSHOT',(select array_agg(source_rank order by seed)=array[1,2]from public.tournament_seeds where bracket_id=pg_temp.td_id('standings-bracket')));
update public.standings_rows set rank=3-rank where scope_id=pg_temp.rb_id('phase6d-overall-scope');
select pg_temp.check('later standings mutation does not rewrite accepted seeds','SNAPSHOT',(select array_agg(source_rank order by seed)=array[1,2]from public.tournament_seeds where bracket_id=pg_temp.td_id('standings-bracket')));

set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.td('bracket.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'name','Synthetic unresolved-tie bracket','bracket_size',2),'tie-bracket');
reset role;
update public.standings_rows set rank=1 where scope_id=pg_temp.rb_id('phase6d-overall-scope');
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.denied('unresolved equal standings ranks cannot invent seeds',format('select public.boss_tournament_mutate(%L::jsonb)',jsonb_build_object('action','bracket.seed','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('tie-bracket'),'expected_version',1,'source_kind','standings_snapshot','source_scope_id',pg_temp.rb_id('phase6d-overall-scope'),'reason','Must reject unresolved tie'))),'PT409');
reset role;

set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('standings',null,jsonb_build_object('group_id',pg_temp.rb_id('division'))),'phase6d-group-scope');
reset role;
update public.standings_rows set rank=case when entry_id=pg_temp.rb_id('falcons-entry')then 1 else 2 end where scope_id=pg_temp.rb_id('phase6d-group-scope');
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.td('bracket.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'name','Synthetic group qualification bracket','bracket_size',2),'group-bracket');
select pg_temp.td('bracket.seed',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('group-bracket'),'expected_version',1,'source_kind','group_finish_snapshot','seeds',jsonb_build_array(
 jsonb_build_object('seed',1,'entry_id',pg_temp.rb_id('falcons-entry'),'source_scope_id',pg_temp.rb_id('phase6d-group-scope'),'source_rank',1),
 jsonb_build_object('seed',2,'entry_id',pg_temp.rb_id('wildcats-entry'),'source_scope_id',pg_temp.rb_id('phase6d-group-scope'),'source_rank',2)
),'reason','Disposable explicit group crossover mapping'));
reset role;
select pg_temp.check('group qualification stores explicit scope and rank','GROUP_QUALIFICATION',(select count(*)=2 and bool_and(source_scope_id=pg_temp.rb_id('phase6d-group-scope'))and array_agg(source_rank order by seed)=array[1,2]from public.tournament_seeds where bracket_id=pg_temp.td_id('group-bracket')));

set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.td('bracket.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'name','Synthetic bye bracket','bracket_size',4),'bye-bracket');
select pg_temp.td('bracket.seed',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('bye-bracket'),'expected_version',1,'source_kind','manual','seeds',jsonb_build_array(
 jsonb_build_object('seed',1,'entry_id',pg_temp.rb_id('falcons-entry')),jsonb_build_object('seed',2,'entry_id',pg_temp.rb_id('hawks-entry')),jsonb_build_object('seed',3,'entry_id',pg_temp.rb_id('wildcats-entry'))
),'reason','Disposable deterministic bye acceptance'));
reset role;
select pg_temp.check('bye creates one audited automatic advancement','BYE',(select count(*)=1 and bool_and(advancement_kind='bye')from public.tournament_advancements where bracket_id=pg_temp.td_id('bye-bracket')));
select pg_temp.check('bye creates no fake canonical game','BYE',exists(select 1 from public.tournament_matches where bracket_id=pg_temp.td_id('bye-bracket')and status='bye_complete')and not exists(select 1 from public.tournament_matches where bracket_id=pg_temp.td_id('bye-bracket')and status='bye_complete'and game_id is not null));
select pg_temp.check('bye creates no sport event or statistics','BYE',not exists(select 1 from public.tournament_matches tm join public.game_operations go on go.game_id=tm.game_id where tm.bracket_id=pg_temp.td_id('bye-bracket')));

set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.td('bracket.seed',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('bye-bracket'),'expected_version',2,'source_kind','manual','seeds',jsonb_build_array(
 jsonb_build_object('seed',1,'entry_id',pg_temp.rb_id('wildcats-entry'),'override_reason','Reviewed pre-play change'),jsonb_build_object('seed',2,'entry_id',pg_temp.rb_id('hawks-entry')),jsonb_build_object('seed',3,'entry_id',pg_temp.rb_id('falcons-entry'))
),'reason','Disposable reviewed reseed before play'));
reset role;
select pg_temp.check('pre-play reseed appends a revision','REVISION',(select count(*)=2 and max(revision)=2 from public.tournament_bracket_revisions where bracket_id=pg_temp.td_id('bye-bracket')));
select pg_temp.check('prior seed revision remains immutable history','REVISION',(select count(*)=6 from public.tournament_seeds where bracket_id=pg_temp.td_id('bye-bracket')));
select pg_temp.check('prior structural stages are archived','REVISION',(select count(*)>0 and bool_and(status='archived')from public.tournament_stages where id in(select stage_id from public.tournament_matches where bracket_id=pg_temp.td_id('bye-bracket')and revision_id=(select id from public.tournament_bracket_revisions where bracket_id=pg_temp.td_id('bye-bracket')and revision=1))));

set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.td('bracket.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'name','Synthetic ruling championship','bracket_size',2),'ruling-championship');
select pg_temp.td('bracket.seed',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('ruling-championship'),'expected_version',1,'source_kind','manual','seeds',jsonb_build_array(jsonb_build_object('seed',1,'entry_id',pg_temp.rb_id('falcons-entry')),jsonb_build_object('seed',2,'entry_id',pg_temp.rb_id('wildcats-entry'))),'reason','Disposable championship seed'));
reset role;
insert into pg_temp.phase6d_ids select'championship-match',id from public.tournament_matches where bracket_id=pg_temp.td_id('ruling-championship');
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.td('ruling.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('championship-match'),'expected_version',1,'kind','disqualification','winner_entry_id',pg_temp.rb_id('falcons-entry'),'loser_entry_id',pg_temp.rb_id('wildcats-entry'),'reason','Disposable explicit championship disqualification'),'championship-ruling');
reset role;
select pg_temp.check('championship ruling derives champion and complete state','CHAMPION',(select champion_entry_id=pg_temp.rb_id('falcons-entry')and status='complete'from public.tournament_brackets where id=pg_temp.td_id('ruling-championship')));
select pg_temp.check('champion notification enqueued once','NOTIFICATION',(select count(*)=1 from public.notification_events ne where ne.source_type='tournament_advancement'and ne.event_type='tournament.champion'and ne.source_id in(select id from public.tournament_advancements where bracket_id=pg_temp.td_id('ruling-championship'))));
select pg_temp.check('notification contains no roster or athlete payload','PRIVACY',(select bool_and(not(safe_data?'person_id')and not(safe_data?'participant_id'))from public.notification_events where source_type='tournament_advancement'));

select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
