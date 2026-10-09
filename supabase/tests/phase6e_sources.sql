begin;
set local statement_timeout='8s';
\ir phase6e/fixture.sql
-- A second genuine canonical game gives both athletes one home run.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dd_create('pe-tie-game','baseball','essential');
select public.boss_stat_competition_classify(pg_temp.ff_game('pe-tie-game'),'official','Synthetic co-holder source',gen_random_uuid());
do $$declare n int;begin
 for n in 1..3 loop perform pg_temp.dd_pa('pe-tie-game','pe-top-'||n);perform pg_temp.dd_play('pe-tie-game','other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;
 perform pg_temp.dd_op('diamond.half.start','pe-tie-game','{"payload":{"kind":"half_start"}}');perform pg_temp.dd_pa('pe-tie-game','pe-bottom-homer');perform pg_temp.dd_play('pe-tie-game','home_run',jsonb_build_array(pg_temp.dd_move(0,4)));
 for n in 1..3 loop perform pg_temp.dd_pa('pe-tie-game','pe-bottom-'||n);perform pg_temp.dd_play('pe-tie-game','other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;perform pg_temp.game_op('game.finalize','pe-tie-game');end$$;
select(public.boss_athlete_profile_mutate(jsonb_build_object('action','profile.create','request_id',gen_random_uuid(),'input',jsonb_build_object('participant_id',pg_temp.f('participant-child2'),'visibility','athlete_guardian','safe_fields',jsonb_build_object('display_name','Synthetic Child Two'))))->>'profile_id')::uuid pe_profile2 \gset
insert into pg_temp.phase6e_ids values('profile2',:'pe_profile2');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'season_id',pg_temp.f('season'),'product','records','source_kind','athlete_season','name','Synthetic tied home-run record','metric_key','home_runs','metric_kind','count','direction','high','qualification','{}'::jsonb,'competition_only',false),'pe-record');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('records','pe-record'),'pe-record-scope');
select pg_temp.pe_definition('record_badge',jsonb_build_object('name','Synthetic record holder','subject_type','athlete','category','record','source_kind','record','sport_key','baseball','ranking_definition_id',pg_temp.rb_id('pe-record'),'historical_evaluation',true,'showcase_eligible',false));
select pg_temp.pe_evaluate('record_badge');
reset role;
select pg_temp.check('two genuine canonical co-holders recognized','CO_HOLDER',(select count(*)=2 and bool_and(co_holder and current_holder)from public.achievement_recognitions where source_type='record_event'));
select pg_temp.check('record event references are canonical','RECORD',(select bool_and(exists(select 1 from public.record_events e where e.id=r.source_id))from public.achievement_recognitions r where r.source_type='record_event'));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'season_id',pg_temp.f('season'),'product','leaderboard','source_kind','athlete_season','name','Synthetic tied leaders','metric_key','home_runs','metric_kind','count','direction','high','qualification','{}'::jsonb,'competition_only',false),'pe-leader');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','pe-leader'));
select pg_temp.pe_definition('leader_badge',jsonb_build_object('name','Synthetic season leader','subject_type','athlete','category','leaderboard','source_kind','leaderboard','sport_key','baseball','ranking_definition_id',pg_temp.rb_id('pe-leader'),'placement',1,'historical_evaluation',true));select pg_temp.pe_evaluate('leader_badge');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'season_id',pg_temp.f('season'),'product','leaderboard','source_kind','athlete_season','name','Synthetic unqualified rate','metric_key','avg','metric_kind','rate','direction','high','qualification','{"thresholds":[{"type":"min_pa","value":50}]}'::jsonb,'competition_only',false),'pe-rate');select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','pe-rate'));
select pg_temp.pe_definition('rate_badge',jsonb_build_object('name','Synthetic qualified rate leader','subject_type','athlete','category','leaderboard','source_kind','leaderboard','sport_key','baseball','ranking_definition_id',pg_temp.rb_id('pe-rate'),'placement',1,'historical_evaluation',true));select pg_temp.pe_evaluate('rate_badge');
reset role;
select pg_temp.check('tied leaders both receive honest recognition','LEADERBOARD',(select count(*)=2 from public.achievement_recognitions r join public.achievement_definition_revisions d on d.id=r.definition_revision_id where d.definition_id=pg_temp.pe_id('leader_badge')));
update public.ranking_scopes set valid_until=clock_timestamp()+interval '50 milliseconds' where definition_id=pg_temp.rb_id('pe-leader');
select pg_sleep(0.07);
select pg_temp.check('ranking validity expiry uses live clock inside transaction','FRESHNESS',not exists(select 1 from boss_private.achievement_facts((select r from public.achievement_definition_revisions r where r.definition_id=pg_temp.pe_id('leader_badge')),pg_temp.f('org'))fact where(fact->>'qualifies')::boolean));
update public.ranking_scopes set valid_until=null where definition_id=pg_temp.rb_id('pe-leader');
select pg_temp.check('unqualified rate creates no award','RATE',not exists(select 1 from public.achievement_recognitions r join public.achievement_definition_revisions d on d.id=r.definition_revision_id where d.definition_id=pg_temp.pe_id('rate_badge')));
-- A qualified label from a partial-cohort ranking is insufficient for a rate badge.
update public.ranking_candidates set qualification_state='qualified',rank=1,coverage='{"source_games":2,"complete_games":1,"partial_allowed":true}'where scope_id in(select id from public.ranking_scopes where definition_id=pg_temp.rb_id('pe-rate'));
select pg_temp.check('partial qualified rate still cannot earn a badge','RATE',not exists(select 1 from boss_private.achievement_facts((select r from public.achievement_definition_revisions r where r.definition_id=pg_temp.pe_id('rate_badge')),pg_temp.f('org'))fact where(fact->>'qualifies')::boolean));

set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('guardian badge cannot disclose private peer rank','AUDIENCE',not exists(select 1 from jsonb_array_elements(public.boss_achievement_read(jsonb_build_object('profile_id',pg_temp.pe_id('profile')))->'recognitions')x where x->>'category'in('record','leaderboard')));
select pg_temp.actor('admin');
select pg_temp.denied('restricted leaderboard cannot become showcase badge',format('select public.boss_achievement_mutate(%L::jsonb)',jsonb_build_object('action','definition.create','request_id',gen_random_uuid(),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'owner_kind','organization','definition_key','rank_leak','revision',jsonb_build_object('name','Private rank leak','subject_type','athlete','category','leaderboard','source_kind','leaderboard','sport_key','baseball','ranking_definition_id',pg_temp.rb_id('pe-leader'),'placement',1,'showcase_eligible',true)))),'PT422');
select pg_temp.rb('policy.activate',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'configuration',pg_temp.rb_policy(),'reason','Synthetic approved completed league policy'));
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('standings',null,jsonb_build_object('group_id',pg_temp.rb_id('division'))),'pe-standings');
select pg_temp.pe('standings.close',jsonb_build_object('scope_id',pg_temp.rb_id('pe-standings'),'reason','Synthetic completed unique champion'));
select pg_temp.pe_definition('standings_badge',jsonb_build_object('name','Synthetic league champion','subject_type','team','category','standings','source_kind','standings','sport_key','baseball','standings_scope_id',pg_temp.rb_id('pe-standings'),'placement',1,'historical_evaluation',true));select pg_temp.pe_evaluate('standings_badge');
reset role;
select pg_temp.check('standings champion requires canonical close decision','STANDINGS',(select count(*)=1 from public.achievement_recognitions where source_type='standings_scope'));
-- Explicit tournament rulings never invent individual scoring/MVP facts.
insert into pg_temp.phase6d_ids select'pe-semi1',id from public.tournament_matches where bracket_id=pg_temp.td_id('bracket')and round_number=1 and match_number=1;
insert into pg_temp.phase6d_ids select'pe-semi2',id from public.tournament_matches where bracket_id=pg_temp.td_id('bracket')and round_number=1 and match_number=2;
insert into pg_temp.phase6d_ids select'pe-final',id from public.tournament_matches where bracket_id=pg_temp.td_id('bracket')and label='Round 2 · Match 1';
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.td('ruling.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('pe-semi1'),'expected_version',1,'kind','forfeit','winner_entry_id',pg_temp.rb_id('falcons-entry'),'loser_entry_id',pg_temp.rb_id('wildcats-entry'),'reason','Synthetic semifinal ruling'));
select pg_temp.td('ruling.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('pe-semi2'),'expected_version',1,'kind','forfeit','winner_entry_id',pg_temp.rb_id('hawks-entry'),'loser_entry_id',pg_temp.rb_id('eagles-entry'),'reason','Synthetic semifinal ruling'));
select pg_temp.td('ruling.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('pe-final'),'expected_version',3,'kind','forfeit','winner_entry_id',pg_temp.rb_id('falcons-entry'),'loser_entry_id',pg_temp.rb_id('hawks-entry'),'reason','Synthetic final ruling'));
select pg_temp.pe_definition('champion_badge',jsonb_build_object('name','Synthetic tournament champion','subject_type','team','category','tournament','source_kind','tournament','sport_key','baseball','bracket_id',pg_temp.td_id('bracket'),'placement',1,'historical_evaluation',true));select pg_temp.pe_evaluate('champion_badge');
select pg_temp.pe_definition('athlete_champion',jsonb_build_object('name','Synthetic athlete tournament honor','subject_type','athlete','category','tournament','source_kind','tournament','sport_key','baseball','bracket_id',pg_temp.td_id('bracket'),'placement',1,'athlete_championship_policy','sealed_participation','historical_evaluation',true));select pg_temp.pe_evaluate('athlete_champion');
reset role;
select pg_temp.check('canonical team tournament championship recognized','TOURNAMENT',(select count(*)=1 from public.achievement_recognitions r join public.achievement_definition_revisions d on d.id=r.definition_revision_id where d.definition_id=pg_temp.pe_id('champion_badge')and r.team_id=pg_temp.f('falcons')));
select pg_temp.check('current roster alone cannot earn individual title','ELIGIBILITY',not exists(select 1 from public.achievement_recognitions r join public.achievement_definition_revisions d on d.id=r.definition_revision_id where d.definition_id=pg_temp.pe_id('athlete_champion')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.game_op('game.reopen','ranking-game','{"reason":"Synthetic record correction"}');select public.boss_stat_competition_classify(pg_temp.ff_game('ranking-game'),'excluded','Synthetic source exclusion',gen_random_uuid());select pg_temp.game_op('game.finalize','ranking-game');
reset role;select boss_private.stat_refresh(pg_temp.ff_game('ranking-game'));set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('records','pe-record'));select pg_temp.pe_evaluate('record_badge');
reset role;
select pg_temp.check('record source correction invalidates current badge','CORRECTION',(select r.state='corrected'and not r.current_holder from public.achievement_recognitions r where r.person_id=pg_temp.f('child1')and r.source_type='record_event'));
select pg_temp.check('co-holder becomes sole holder without tie fabrication','CO_HOLDER',(select r.state='current'and r.current_holder and not r.co_holder from public.achievement_recognitions r where r.person_id=pg_temp.f('child2')and r.source_type='record_event'));
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
