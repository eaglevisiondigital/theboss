begin;
set local statement_timeout='8s';
\ir phase6d/fixture.sql
do $$declare tab text;client text;privileges bigint;begin
 foreach tab in array array['tournament_stages','tournament_brackets','tournament_bracket_revisions','tournament_seeds','tournament_matches','tournament_advancements','tournament_rulings']loop
  perform pg_temp.check(tab||' RLS enabled','RLS',(select relrowsecurity from pg_class where oid=('public.'||tab)::regclass));
  foreach client in array array['anon','authenticated','service_role']loop select count(*)into privileges from information_schema.role_table_grants where table_schema='public'and table_name=tab and grantee=client;perform pg_temp.check(tab||' closed to '||client,'ACL',privileges=0);end loop;
 end loop;
end$$;
select pg_temp.check('private receipts closed','ACL',not has_table_privilege('authenticated','boss_private.tournament_operation_receipts','select'));
select pg_temp.check('anon cannot execute read','ACL',not has_function_privilege('anon','public.boss_tournament_read(jsonb)','execute'));
select pg_temp.check('anon cannot execute mutation','ACL',not has_function_privilege('anon','public.boss_tournament_mutate(jsonb)','execute'));
select pg_temp.denied('bracket revision immutable',format('update public.tournament_bracket_revisions set reason=''changed''where bracket_id=%L',pg_temp.td_id('bracket')),'23514');
select pg_temp.denied('seed immutable',format('delete from public.tournament_seeds where bracket_id=%L',pg_temp.td_id('bracket')),'23514');
insert into pg_temp.phase6d_ids select'security-match-one',id from public.tournament_matches where bracket_id=pg_temp.td_id('bracket')and round_number=1 and match_number=1;
insert into pg_temp.phase6d_ids select'security-final',id from public.tournament_matches where bracket_id=pg_temp.td_id('bracket')and label='Round 2 · Match 1';
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('edition.create',jsonb_build_object('competition_id',pg_temp.rb_id('competition'),'sport_key','baseball','name','Synthetic neighboring tournament edition','team_result_audience','managers'),'other-edition');
select pg_temp.denied('forged bracket read denied',format('select public.boss_tournament_read(%L::jsonb)',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',gen_random_uuid())),'PT403');
select pg_temp.denied('forged edition mutation denied',format('select public.boss_tournament_mutate(%L::jsonb)',jsonb_build_object('action','bracket.create','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',gen_random_uuid(),'name','Forged','bracket_size',4))),'PT403');
select pg_temp.denied('foreign canonical game cannot link',format('select public.boss_tournament_mutate(%L::jsonb)',jsonb_build_object('action','match.link_game','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('security-match-one'),'expected_version',1,'game_id',pg_temp.ff_game('ranking-game')))),'PT422');
select pg_temp.denied('unready downstream match cannot link',format('select public.boss_tournament_mutate(%L::jsonb)',jsonb_build_object('action','match.link_game','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('security-final'),'expected_version',1,'game_id',(select id from pg_temp.phase5a_games where label='tournament-first')))),'PT409');
select pg_temp.denied('unfinalized game cannot advance',format('select public.boss_tournament_mutate(%L::jsonb)',jsonb_build_object('action','result.process','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('security-match-one'),'expected_version',1,'reason','Forbidden premature result'))),'PT422');
select pg_temp.denied('seed entry from another edition rejected',format('select public.boss_tournament_mutate(%L::jsonb)',jsonb_build_object('action','bracket.seed','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('bracket'),'expected_version',2,'source_kind','manual','seeds',jsonb_build_array(jsonb_build_object('seed',1,'entry_id',pg_temp.rb_id('falcons-entry')),jsonb_build_object('seed',2,'entry_id',pg_temp.rb_id('foreign-entry'))),'reason','Forbidden cross-edition seed'))),'PT422');
select pg_temp.actor('coach');select pg_temp.check('exact team coach gets safe view','AUTHORIZATION',jsonb_array_length(public.boss_tournament_read(jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('bracket')))->'matches')=4);select pg_temp.denied('coach cannot manage tournament',format('select public.boss_tournament_mutate(%L::jsonb)',jsonb_build_object('action','bracket.archive','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('bracket'),'expected_version',2))),'PT403');
select pg_temp.actor('admin');select pg_temp.rb('access.grant',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'person_id',pg_temp.f('household-only'),'ends_at',clock_timestamp()+interval'1 hour'),'td-manager');select pg_temp.actor('household-only');
select pg_temp.check('exact competition manager can manage bracket','AUTHORIZATION',public.boss_tournament_read(jsonb_build_object('edition_id',pg_temp.rb_id('edition')))->>'can_manage'='true');
select pg_temp.denied('manager cannot access neighboring edition',format('select public.boss_tournament_read(%L::jsonb)',jsonb_build_object('edition_id',pg_temp.rb_id('other-edition'))),'PT403');
select pg_temp.actor('admin');select pg_temp.rb('access.end',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'assignment_id',pg_temp.rb_id('td-manager')));select pg_temp.actor('household-only');select pg_temp.denied('stale manager denied after revocation',format('select public.boss_tournament_read(%L::jsonb)',jsonb_build_object('edition_id',pg_temp.rb_id('edition'))),'PT403');
reset role;
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
