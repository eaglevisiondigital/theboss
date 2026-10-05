-- Additional isolated canonical NULL-season/classification lifecycle proof.
begin;
\ir phase5f/fixture.sql
-- Existing synthetic Tigers has NULL season. Keep Child1's persistent identity;
-- no extra guardian, account, role, person or season is created.
insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,jersey_number,starts_at)
values(pg_temp.f('org'),pg_temp.f('tigers'),pg_temp.f('child1'),pg_temp.f('participant-child1'),'athlete','12',now()-interval '1 day');
select pg_temp.ff_clone_event('unassigned','internal');
delete from public.event_targets where event_id=pg_temp.f('event-ff-unassigned')and target_type='team'and target_id=pg_temp.f('falcons');
insert into public.event_targets(event_id,organization_id,target_type,target_id)values(pg_temp.f('event-ff-unassigned'),pg_temp.f('org'),'team',pg_temp.f('tigers'));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.create_game('unassigned','ff-unassigned','tigers','baseball');
select pg_temp.game_op('game.roster.snapshot','unassigned');
select pg_temp.game_op('game.operator.assign','unassigned',jsonb_build_object('person_id',pg_temp.f('admin'),'role_assignment_id',pg_temp.f('role-admin'),'function_key','game_administrator','team_id',pg_temp.f('tigers'),'ends_at',clock_timestamp()+interval '1 hour'));
select pg_temp.dd_profile('unassigned','primary','essential');select pg_temp.dd_profile('unassigned','opponent','essential');
select pg_temp.dd_op('diamond.configure','unassigned',jsonb_build_object('configuration',pg_temp.dd_config('baseball')));
do $$declare sd text;rid uuid;begin
foreach sd in array array['primary','opponent']loop
rid:=pg_temp.ff_roster('unassigned',sd,1);
perform pg_temp.dd_op('diamond.lineup.set','unassigned',jsonb_build_object('payload',jsonb_build_object('kind','lineup_set','side',sd,'order',jsonb_build_array(rid,null,null,null),'positions',jsonb_build_object('1',rid),'pitcher',rid)));
end loop;end$$;
select public.boss_stat_competition_classify(pg_temp.ff_game('unassigned'),'official','Disposable explicit official NULL-season proof',md5('phase6a-unassigned-official')::uuid);
select pg_temp.game_op('game.start','unassigned');select pg_temp.dd_op('diamond.half.start','unassigned','{"payload":{"kind":"half_start"}}');
select pg_temp.dd_pa('unassigned','null-season-hr');select pg_temp.dd_play('unassigned','home_run',jsonb_build_array(pg_temp.dd_move(0,4)));
do $$declare h int;i int;begin for h in 1..2 loop
for i in 1..3 loop perform pg_temp.dd_pa('unassigned','null-'||h||'-'||i);perform pg_temp.dd_play('unassigned','other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;
if h=1 then perform pg_temp.dd_op('diamond.half.start','unassigned','{"payload":{"kind":"half_start"}}');end if;end loop;
perform pg_temp.game_op('game.finalize','unassigned');end$$;
reset role;select boss_private.stat_refresh(pg_temp.ff_game('unassigned'));
select pg_temp.check('native creation preserves NULL canonical game season','UNASSIGNED',(select season_id is null from public.games where id=pg_temp.ff_game('unassigned')));
select pg_temp.check('sealed contributions retain NULL rather than opponent season','UNASSIGNED',(select bool_and(season_id is null)from public.stat_game_contributions where game_id=pg_temp.ff_game('unassigned')));
select pg_temp.check('persistent Child1 participant retained in seasonless origin','PROVENANCE',(select bool_and(participant_id=pg_temp.f('participant-child1')and team_id=pg_temp.f('tigers'))from public.stat_game_contributions where game_id=pg_temp.ff_game('unassigned')and person_id=pg_temp.f('child1')));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('authorized career includes unassigned count','UNASSIGNED',(public.boss_athlete_career_read(jsonb_build_object('person_id',pg_temp.f('child1'),'sport_key','baseball'))->>'unassigned_game_count')::int=1);
select pg_temp.check('named season excludes NULL source','UNASSIGNED',(public.boss_athlete_season_read(jsonb_build_object('person_id',pg_temp.f('child1'),'sport_key','baseball','season_id',pg_temp.f('season')))->'summary'->>'source_game_count')::int=0);
select pg_temp.check('career GP comes from positive accepted appearance','GP',(public.boss_athlete_career_read(jsonb_build_object('person_id',pg_temp.f('child1'),'sport_key','baseball'))->'summary'->>'confirmed_gp')::int=1);
reset role;
update public.games set schedule_status='archived',publication_state='unpublished'where id=pg_temp.ff_game('unassigned');
select boss_private.stat_refresh(pg_temp.ff_game('unassigned'));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('archive/unpublish preserves eligible official career','ARCHIVAL',(public.boss_athlete_career_read(jsonb_build_object('person_id',pg_temp.f('child1'),'sport_key','baseball'))->'summary'->>'source_game_count')::int=1);
reset role;update public.games set schedule_status='confirmed' where id=pg_temp.ff_game('unassigned');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.game_op('game.reopen','unassigned','{"reason":"Disposable controlled classification correction"}');
select public.boss_stat_competition_classify(pg_temp.ff_game('unassigned'),'controlled_test','Explicit controlled exclusion for next authoritative epoch',md5('phase6a-unassigned-controlled')::uuid);
select pg_temp.game_op('game.finalize','unassigned');
reset role;select boss_private.stat_refresh(pg_temp.ff_game('unassigned'));
select pg_temp.check('both immutable classification versions retained','CLASSIFICATION',(select count(*)=2 from public.stat_competition_classifications where game_id=pg_temp.ff_game('unassigned')));
select pg_temp.check('classification binds only correct authoritative epoch','CLASSIFICATION',(select bool_and(case epoch when 1 then classification='official'else classification='controlled_test'end)from public.stat_game_contributions where game_id=pg_temp.ff_game('unassigned')));
select pg_temp.check('sole current selector points to controlled second epoch','EPOCH',(select f.epoch=2 and s.generation=s.refreshed_generation from public.stat_game_selections s join public.game_finalizations f on f.id=s.finalization_id where s.game_id=pg_temp.ff_game('unassigned')));
select pg_temp.check('old official epoch evidence not deleted','HISTORY',exists(select 1 from public.stat_game_contributions where game_id=pg_temp.ff_game('unassigned')and epoch=1 and classification='official'));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('controlled-test epoch removed from official career','CLASSIFICATION',(public.boss_athlete_career_read(jsonb_build_object('person_id',pg_temp.f('child1'),'sport_key','baseball'))->'summary'->>'source_game_count')::int=0);
reset role;
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
