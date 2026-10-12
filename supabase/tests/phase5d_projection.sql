-- Literal regression for dependent field display after an earlier correction.
-- Raw captured context stays immutable; active display follows accepted history.
begin;
\ir phase5d/fixture.sql
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.ff_create('projection-replay');
select pg_temp.ff_play('projection-replay','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('projection-replay','primary',2),'yards',4),'projection-source');
select pg_temp.ff_play('projection-replay','pass_complete','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('projection-replay','primary',1),'receiver_roster_id',pg_temp.ff_roster('projection-replay','primary',3),'yards',5),'projection-later');
select pg_temp.ff_op('football.play.correct','projection-replay',jsonb_build_object('event_id',pg_temp.ff_event_id('projection-replay','projection-source'),'play_type','rush','side','primary','roster_id',pg_temp.ff_roster('projection-replay','primary',2),'yards',5,'reason','Synthetic reviewed earlier yardage'),'projection-correction');
select pg_temp.check('active PBP later play shows rebuilt 35-to40 first down','PROJECTION',
 (select p->'before_field'->>'ball_spot'='35' and p->'before_field'->>'down'='2' and p->'before_field'->>'distance'='5'
 and p->'after_field'->>'ball_spot'='40' and p->'after_field'->>'down'='1' and p->'after_field'->>'distance'='10'
 from jsonb_array_elements(pg_temp.ff_detail('projection-replay')->'plays')p where p->>'id'=pg_temp.ff_event_id('projection-replay','projection-later')::text));
select pg_temp.check('private correction selector uses the same rebuilt later field','PROJECTION',
 (select p->'before_field'->>'ball_spot'='35' and p->'after_field'->>'down'='1'
 from jsonb_array_elements(pg_temp.ff_detail('projection-replay')->'entry_plays')p where p->>'id'=pg_temp.ff_event_id('projection-replay','projection-later')::text));
select pg_temp.check('projection omits raw correction reasons and actor material','PRIVACY',
 not exists(select 1 from jsonb_array_elements(pg_temp.ff_detail('projection-replay')->'plays')p where p?'reason' or p?'actor_person_id' or p?'request_id'));
reset role;
select pg_temp.check('raw later fact retains captured 34-yard spot','IMMUTABLE',
 (select before_field->>'ball_spot'='34' and after_field->>'down'='3' from public.game_football_events where id=pg_temp.ff_event_id('projection-replay','projection-later')));
select count(*) as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
