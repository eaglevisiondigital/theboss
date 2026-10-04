-- Athlete-history portability/privacy acceptance; disposable only, rollback-only.
-- Real sport commands create seals. No production person, DOB or credential.
begin;
\ir phase5d/fixture.sql
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":true,"basketball_stats":true,"basketball_play_by_play":true,"basketball_lineups":true,"soccer_live_scoring":true,"soccer_stats":true,"soccer_play_by_play":true,"soccer_lineups":true}'
 where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
-- Reuse only the canonical fixture once. These adapters invoke real sport
-- commands on the same persistent subjects, without copying engine formulas.
create function pg_temp.sc_roster(label text,side text,n integer) returns uuid language sql stable as $$
 select pg_temp.ff_roster(label,side,n)
$$;
create function pg_temp.sc_link(label text,event_label text default 'internal',primary_label text default 'falcons',sport text default 'soccer') returns void language sql volatile as $$
 select pg_temp.ff_link(label,event_label,primary_label,sport)
$$;
create function pg_temp.sc_create(label text,event_label text default 'internal',start_game boolean default true,segments int default 2,enforce boolean default false) returns void language plpgsql as $$begin
 perform pg_temp.sc_link(label,event_label);
 perform pg_temp.game_op('soccer.configure',label,jsonb_build_object('regulation_segments',segments,'segment_seconds',60,'extra_time_segments',0,'extra_time_seconds',60,'lineup_size',7,'enforce_lineup',enforce,'allow_reentry',true,'max_substitutions',null));
 if start_game then perform pg_temp.game_op('game.start',label);perform pg_temp.game_op('soccer.segment.start',label);end if;
end$$;
create function pg_temp.sc_event(label text,kind text,side text,n int) returns void language plpgsql as $$begin
 perform pg_temp.game_op('soccer.event.add',label,jsonb_build_object('event_type',kind,'side',side,'roster_id',pg_temp.sc_roster(label,side,n)));
end$$;
create function pg_temp.sc_finish(label text) returns void language plpgsql as $$begin
 perform pg_temp.game_op('soccer.clock.set',label,'{"clock_ms":60000,"reason":"Synthetic history half completion"}');
 perform pg_temp.game_op('soccer.segment.end',label);perform pg_temp.game_op('soccer.segment.start',label);
 perform pg_temp.game_op('soccer.clock.set',label,'{"clock_ms":60000,"reason":"Synthetic history half completion"}');
 perform pg_temp.game_op('soccer.segment.end',label);
end$$;
revoke all on function pg_temp.sc_roster(text,text,integer),pg_temp.sc_link(text,text,text,text),pg_temp.sc_create(text,text,boolean,int,boolean),pg_temp.sc_event(text,text,text,int),pg_temp.sc_finish(text) from public;
grant execute on function pg_temp.sc_roster(text,text,integer),pg_temp.sc_link(text,text,text,text),pg_temp.sc_create(text,text,boolean,int,boolean),pg_temp.sc_event(text,text,text,int),pg_temp.sc_finish(text) to authenticated;
create function pg_temp.history_bb_seal(label text,event_label text default 'history',primary_label text default 'falcons',scorer text default 'child1')
returns void language plpgsql as $$begin
 perform pg_temp.sc_link(label,event_label,primary_label,'basketball');
 perform pg_temp.game_op('basketball.configure',label,'{"regulation_periods":2,"period_seconds":60,"overtime_seconds":60,"lineup_size":5,"enforce_lineup":false}');
 perform pg_temp.game_op('game.start',label);perform pg_temp.game_op('basketball.period.start',label);
 if scorer is not null then
  perform pg_temp.game_op('basketball.event.add',label,jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.sc_roster(label,'primary',1)));
 end if;
 perform pg_temp.game_op('basketball.clock.set',label,'{"clock_ms":0,"reason":"Synthetic history period completion"}');
 perform pg_temp.game_op('basketball.period.end',label);perform pg_temp.game_op('basketball.period.start',label);
 perform pg_temp.game_op('basketball.clock.set',label,'{"clock_ms":0,"reason":"Synthetic history period completion"}');
 perform pg_temp.game_op('basketball.period.end',label);perform pg_temp.game_op('game.finalize',label);
end$$;
create function pg_temp.history_read(extra jsonb default '{}') returns jsonb language sql volatile as $$
 select public.boss_athlete_history_read(jsonb_build_object('child_person_id',pg_temp.f('child1'))||extra)
$$;
revoke all on function pg_temp.history_bb_seal(text,text,text,text),pg_temp.history_read(jsonb) from public;
grant execute on function pg_temp.history_bb_seal(text,text,text,text),pg_temp.history_read(jsonb) to authenticated;
create temp table history_results(label text primary key,payload jsonb not null) on commit drop;
grant select,insert,update on history_results to authenticated,anon;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.history_bb_seal('history-bb');
select pg_temp.sc_create('history-sc','internal',true,2,false);
select pg_temp.sc_event('history-sc','goal','primary',1);
select pg_temp.sc_finish('history-sc');select pg_temp.game_op('game.finalize','history-sc');
select pg_temp.ff_create('history-ff');
select pg_temp.ff_play('history-ff','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('history-ff','primary',1),'yards',-2));
select pg_temp.ff_finish('history-ff');select pg_temp.game_op('game.finalize','history-ff');
select pg_temp.history_bb_seal('history-null-season','sibling','tigers',null);
select pg_temp.actor('parent');
insert into history_results values('initial',pg_temp.history_read());
select pg_temp.check('history selects the current guardian child by default','HISTORY',public.boss_athlete_history_read()->>'subject_person_id'=pg_temp.f('child1')::text);
select pg_temp.check('history returns all three real sport player seals for one persistent athlete','HISTORY',(select jsonb_array_length(payload->'records')=3 and(select count(distinct r->>'sport_key')=3 from jsonb_array_elements(payload->'records')r) from history_results where label='initial'));
select pg_temp.check('history subject list contains dependent and self only','PRIVACY',(select jsonb_array_length(payload->'subjects')=2 and not exists(select 1 from jsonb_array_elements(payload->'subjects')p where p->>'person_id' not in(pg_temp.f('child1')::text,pg_temp.f('parent')::text)) from history_results where label='initial'));
select pg_temp.check('history emits only selected-child stat rows','PRIVACY',(select not exists(select 1 from jsonb_array_elements(payload->'records')r where r->>'person_id'<>pg_temp.f('child1')::text or r->>'participant_id'<>pg_temp.f('participant-child1')::text) from history_results where label='initial'));
select pg_temp.check('Basketball history preserves independent two-point result','ORACLE',(select count(*)=1 and bool_and(r->'stats'->>'points'='2' and r->'stats'->>'fgm'='1' and r->'stats'->>'fga'='1') from history_results h cross join lateral jsonb_array_elements(h.payload->'records')r where h.label='initial' and r->>'sport_key'='basketball'));
select pg_temp.check('Soccer history preserves independent goal result','ORACLE',(select count(*)=1 and bool_and(r->'stats'->>'goals'='1' and r->'stats'->>'shots'='1') from history_results h cross join lateral jsonb_array_elements(h.payload->'records')r where h.label='initial' and r->>'sport_key'='soccer'));
select pg_temp.check('Football history preserves signed yards and nullable longest made field goal','ORACLE',(select count(*)=1 and bool_and(r->'stats'->>'rush_attempts'='1' and r->'stats'->>'rushing_yards'='-2' and r->'stats'->'long_field_goal'='null'::jsonb) from history_results h cross join lateral jsonb_array_elements(h.payload->'records')r where h.label='initial' and r->>'sport_key'='football'));
select pg_temp.check('Soccer incomplete participation stays unknown','RELIABILITY',(select bool_and(r->'stats'->'minutes'='null'::jsonb and r->'stats'->'clean_sheet'='null'::jsonb) from history_results h cross join lateral jsonb_array_elements(h.payload->'records')r where h.label='initial' and r->>'sport_key'='soccer'));
select pg_temp.check('finite sport stats omit profile and raw-engine material','PRIVACY',(select bool_and(not(r->'stats'?'person_id') and not(r->'stats'?'state') and not(r?'display_name') and not(r?'actor_person_id') and not(r?'request_id') and not(r?'household_id')) from history_results h cross join lateral jsonb_array_elements(h.payload->'records')r where h.label='initial'));
select pg_temp.check('complete game provenance accompanies each own player seal','PROVENANCE',(select bool_and(r->>'organization_id'=pg_temp.f('org')::text and r->>'team_id'=pg_temp.f('falcons')::text and r->>'origin_team_season_id'=pg_temp.f('season')::text and r->>'game_season_id'=pg_temp.f('season')::text and(r->>'roster_revision')::bigint>0 and(r->>'epoch')::bigint=1 and(r->>'event_sequence')::bigint>0 and(r->>'operation_sequence')::bigint>0 and r->>'engine_version'=(r->>'sport_key')||'-v1' and(r->>'current_authoritative')::boolean and(r->>'latest_sealed')::boolean) from history_results h cross join lateral jsonb_array_elements(h.payload->'records')r where h.label='initial'));
select pg_temp.check('sport filtering is finite and exact','FILTER',jsonb_array_length(pg_temp.history_read('{"sport_key":"soccer"}')->'records')=1);
select pg_temp.check('unrelated origin-season filter returns no records','FILTER',jsonb_array_length(pg_temp.history_read(jsonb_build_object('season_id',pg_temp.f('not-a-season')))->'records')=0);
select pg_temp.actor('child3');
select pg_temp.check('nullable source seasons are never invented','PROVENANCE',(select jsonb_array_length(h->'records')=1 and h->'records'->0->'origin_team_season_id'='null'::jsonb and h->'records'->0->'origin_team_season_name'='null'::jsonb and h->'records'->0->'game_season_id'='null'::jsonb from(select public.boss_athlete_history_read()h)s));
select pg_temp.actor('admin');
select pg_temp.denied('administrator is not an athlete-history relationship',format('select pg_temp.history_read()'));
select pg_temp.game_op('game.reopen','history-bb','{"reason":"Synthetic sealed history authority review"}');
select pg_temp.actor('parent');
select pg_temp.check('reopened latest seal stays historical without current-final authority','EPOCH',(select count(*)=1 and bool_and(not(r->>'current_authoritative')::boolean and(r->>'latest_sealed')::boolean) from jsonb_array_elements(pg_temp.history_read('{"sport_key":"basketball"}')->'records')r));
select pg_temp.actor('admin');select pg_temp.game_op('game.finalize','history-bb');
select pg_temp.actor('parent');
insert into history_results values('epochs',pg_temp.history_read());
select pg_temp.check('refinalization preserves old epoch and adds a new current epoch','EPOCH',(select count(*)=2 and count(*)filter(where(r->>'current_authoritative')::boolean and(r->>'latest_sealed')::boolean and r->>'epoch'='2')=1 and count(*)filter(where not(r->>'current_authoritative')::boolean and not(r->>'latest_sealed')::boolean and r->>'epoch'='1')=1 from history_results h cross join lateral jsonb_array_elements(h.payload->'records')r where h.label='epochs' and r->>'sport_key'='basketball'));
select pg_temp.check('old seal and stat UUID survive refinalization unchanged','EPOCH',(select count(*)=1 from history_results a cross join lateral jsonb_array_elements(a.payload->'records')old cross join history_results b cross join lateral jsonb_array_elements(b.payload->'records')new where a.label='initial' and b.label='epochs' and old->>'sport_key'='basketball' and old->>'id'=new->>'id' and old->>'finalization_id'=new->>'finalization_id' and old->'stats'=new->'stats'));
insert into history_results values('page1',pg_temp.history_read('{"limit":1}'));
insert into history_results select 'page2',pg_temp.history_read(jsonb_build_object('limit',1,'before_sealed_at',payload->'next_cursor'->>'sealed_at','before_finalization_id',payload->'next_cursor'->>'finalization_id','before_stat_id',payload->'next_cursor'->>'stat_id')) from history_results where label='page1';
insert into history_results select 'page3',pg_temp.history_read(jsonb_build_object('limit',1,'before_sealed_at',payload->'next_cursor'->>'sealed_at','before_finalization_id',payload->'next_cursor'->>'finalization_id','before_stat_id',payload->'next_cursor'->>'stat_id')) from history_results where label='page2';
insert into history_results select 'page4',pg_temp.history_read(jsonb_build_object('limit',1,'before_sealed_at',payload->'next_cursor'->>'sealed_at','before_finalization_id',payload->'next_cursor'->>'finalization_id','before_stat_id',payload->'next_cursor'->>'stat_id')) from history_results where label='page3';
select pg_temp.check('keyset pages have bounded nonduplicate rows','PAGINATION',(select count(*)=4 and count(distinct payload->'records'->0->>'id')=4 and bool_and(jsonb_array_length(payload->'records')=1) from history_results where label in('page1','page2','page3','page4')));
select pg_temp.check('final page has no fabricated continuation cursor','PAGINATION',(select not(payload->>'has_more')::boolean and payload->'next_cursor'='null'::jsonb from history_results where label='page4'));
select pg_temp.check('earlier keyset pages truthfully expose continuation','PAGINATION',(select bool_and((payload->>'has_more')::boolean and jsonb_typeof(payload->'next_cursor')='object') from history_results where label in('page1','page2','page3')));

-- Finite query rejection and privilege-isolation checks.
do $$declare bad jsonb;n integer:=0;begin
 for bad in select * from(values
 ('{"organization_id":"forged"}'::jsonb),('{"roster_id":"forged"}'),('{"limit":0}'),('{"limit":51}'),
 ('{"limit":-1}'),('{"limit":1.2}'),('{"limit":"1"}'),('{"sport_key":"baseball"}'),
 ('{"child_person_id":"bad-uuid"}'),('{"child_person_id":null}'),('{"season_id":null}'),
 ('{"before_sealed_at":"infinity","before_finalization_id":"00000000-0000-0000-0000-000000000000","before_stat_id":"00000000-0000-0000-0000-000000000000"}'),
 ('{"before_stat_id":"00000000-0000-0000-0000-000000000000"}'),
 ('{"before_sealed_at":"not-a-time","before_finalization_id":"00000000-0000-0000-0000-000000000000","before_stat_id":"00000000-0000-0000-0000-000000000000"}'),
 ('[]'),('null')
 )v(q)loop
 n:=n+1;perform pg_temp.denied('finite athlete history query rejection '||n,format('select public.boss_athlete_history_read(%L::jsonb)',bad),'PT422');
 end loop;
end$$;
select pg_temp.denied('private rows cannot bypass subject authorization',format('select * from boss_private.athlete_history_rows(%L,null,null,null,null,null,20)',pg_temp.f('child2')),'42501');
select pg_temp.denied('raw sealed source remains closed','select * from public.game_basketball_final_stats','42501');
select pg_temp.denied('unrelated child2 remains denied',format('select public.boss_athlete_history_read(%L)',jsonb_build_object('child_person_id',pg_temp.f('child2'))));
select pg_temp.denied('unrelated child3 remains denied',format('select public.boss_athlete_history_read(%L)',jsonb_build_object('child_person_id',pg_temp.f('child3'))));
select pg_temp.actor('household-only');select pg_temp.denied('household membership is not guardian history authority','select pg_temp.history_read()');
select pg_temp.actor('coach');select pg_temp.denied('old-team coaching is not guardian history authority','select pg_temp.history_read()');
select pg_temp.actor('other-admin');select pg_temp.denied('unrelated organization administrator cannot read athlete history','select pg_temp.history_read()');
select pg_temp.actor('child2');select pg_temp.denied('athlete cannot forge another athlete subject','select pg_temp.history_read()');

reset role;
create temp table history_sealed_rosters as select * from public.game_roster_snapshots where game_id in(select id from phase5a_games);
create temp table history_sealed_core as select * from public.game_finalizations where game_id in(select id from phase5a_games);
create temp table history_sealed_bb as select * from public.game_basketball_final_stats where game_id in(select id from phase5a_games);
create temp table history_sealed_sc as select * from public.game_soccer_final_stats where game_id in(select id from phase5a_games);
create temp table history_sealed_ff as select * from public.game_football_final_stats where game_id in(select id from phase5a_games);
-- Transfer the SAME persistent person/participant to another existing tenant.
update public.team_memberships set status='inactive',ends_at=clock_timestamp() where person_id=pg_temp.f('child1');
update public.organization_memberships set status='inactive',ends_at=clock_timestamp() where person_id in(pg_temp.f('child1'),pg_temp.f('parent'));
insert into public.organization_memberships(organization_id,person_id,starts_at) values(pg_temp.f('other-org'),pg_temp.f('child1'),clock_timestamp());
insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at) values(pg_temp.f('other-org'),pg_temp.f('other-team'),pg_temp.f('child1'),pg_temp.f('participant-child1'),'athlete',clock_timestamp());
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('guardian history survives same-person cross-organization transfer','TRANSFER',jsonb_array_length(pg_temp.history_read()->'records')=4);
select pg_temp.actor('child1');
select pg_temp.check('athlete self history survives cross-organization transfer','TRANSFER',jsonb_array_length(public.boss_athlete_history_read()->'records')=4);
select pg_temp.actor('other-admin');select pg_temp.denied('new organization staff inherit no original athlete history','select pg_temp.history_read()');
reset role;
update public.participants set status='archived' where person_id=pg_temp.f('child1');
update public.organization_modules set status='inactive',ends_at=clock_timestamp(),configuration='{}' where organization_id=pg_temp.f('org');
update public.seasons set status='archived' where organization_id=pg_temp.f('org');
update public.teams set status='archived' where organization_id=pg_temp.f('org');
update public.organization_units set status='archived' where organization_id=pg_temp.f('org');
update public.organizations set status='archived' where id=pg_temp.f('org');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('archived original source and disabled sport/calendar modules do not erase guardian history','TRANSFER',jsonb_array_length(pg_temp.history_read()->'records')=4);
select pg_temp.check('transfer does not relabel old immutable team or organization','PROVENANCE',(select bool_and(r->>'organization_id'=pg_temp.f('org')::text and r->>'team_id'=pg_temp.f('falcons')::text) from jsonb_array_elements(pg_temp.history_read()->'records')r));
select pg_temp.denied('existing Game Center family RPC keeps original-context denial','select public.boss_games_read(pg_temp.query(null,''{"view":"family"}''))');
reset role;
select pg_temp.check('immutable roster records byte-preserved after transfer/archive','IMMUTABLE',not exists(select 1 from history_sealed_rosters p left join public.game_roster_snapshots n on n.id=p.id where to_jsonb(p) is distinct from to_jsonb(n)));
select pg_temp.check('immutable core seals byte-preserved after transfer/archive','IMMUTABLE',not exists(select 1 from history_sealed_core p left join public.game_finalizations n on n.id=p.id where to_jsonb(p) is distinct from to_jsonb(n)));
select pg_temp.check('immutable Basketball player totals byte-preserved after transfer/archive','IMMUTABLE',not exists(select 1 from history_sealed_bb p left join public.game_basketball_final_stats n on n.id=p.id where to_jsonb(p) is distinct from to_jsonb(n)));
select pg_temp.check('immutable Soccer player totals byte-preserved after transfer/archive','IMMUTABLE',not exists(select 1 from history_sealed_sc p left join public.game_soccer_final_stats n on n.id=p.id where to_jsonb(p) is distinct from to_jsonb(n)));
select pg_temp.check('immutable Football player totals byte-preserved after transfer/archive','IMMUTABLE',not exists(select 1 from history_sealed_ff p left join public.game_football_final_stats n on n.id=p.id where to_jsonb(p) is distinct from to_jsonb(n)));
update public.guardian_relationships set authority_status='inactive' where id=pg_temp.f('guardian-child1');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('guardian revocation immediately denies selected history','select pg_temp.history_read()');
select pg_temp.check('revoked guardian disappears from subject choices','REVOCATION',(select jsonb_array_length(h->'subjects')=1 and jsonb_array_length(h->'records')=0 and h->>'subject_person_id'=pg_temp.f('parent')::text from(select public.boss_athlete_history_read()h)s));
select pg_temp.denied('old valid cursor cannot survive guardian revocation',format('select public.boss_athlete_history_read(%L)',(select jsonb_build_object('child_person_id',pg_temp.f('child1'),'before_sealed_at',payload->'next_cursor'->>'sealed_at','before_finalization_id',payload->'next_cursor'->>'finalization_id','before_stat_id',payload->'next_cursor'->>'stat_id') from history_results where label='page1')));
select pg_temp.actor('child1');
select pg_temp.check('guardian revocation does not revoke active athlete self history','REVOCATION',jsonb_array_length(public.boss_athlete_history_read()->'records')=4);
reset role;
update public.guardian_relationships set authority_status='active',ends_at=clock_timestamp()-interval '1 second' where id=pg_temp.f('guardian-child1');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('natural guardian expiry denies history','select pg_temp.history_read()');
reset role;
update public.guardian_relationships set ends_at=null,verified_at=clock_timestamp()+interval '1 day' where id=pg_temp.f('guardian-child1');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('future guardian verification is not current authority','select pg_temp.history_read()');
reset role;
update public.guardian_relationships set verified_at=now()-interval '3 days' where id=pg_temp.f('guardian-child1');
update public.people set status='suspended' where id=pg_temp.f('child1');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('suspended subject person denies guardian history','select pg_temp.history_read()');
reset role;
update public.people set status='active' where id=pg_temp.f('child1');
update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id=pg_temp.f('session-parent');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('native expired session denies history','select pg_temp.history_read()','PT401');
reset role;
update auth.sessions set not_after=null where id=pg_temp.f('session-parent');
set local role anon;
select pg_temp.denied('anonymous history wrapper execution remains closed','select public.boss_athlete_history_read()','42501');
reset role;
select pg_temp.check('athlete history public wrapper uses invoker permissions','PRIVILEGES',(select not prosecdef from pg_proc where oid='public.boss_athlete_history_read(jsonb)'::regprocedure));
select pg_temp.check('private source helper has no authenticated execute','PRIVILEGES',not has_function_privilege('authenticated','boss_private.athlete_history_rows(uuid,text,uuid,timestamptz,uuid,uuid,integer)','EXECUTE'));
select pg_temp.check('raw Basketball seals still have no authenticated select','PRIVILEGES',not has_table_privilege('authenticated','public.game_basketball_final_stats','SELECT'));
select pg_temp.check('raw Soccer seals still have no authenticated select','PRIVILEGES',not has_table_privilege('authenticated','public.game_soccer_final_stats','SELECT'));
select pg_temp.check('raw Football seals still have no authenticated select','PRIVILEGES',not has_table_privilege('authenticated','public.game_football_final_stats','SELECT'));
select count(*) passed_assertions,'Phase 5D athlete history authorization/portability' acceptance_result from phase5a_assertions;
rollback;
