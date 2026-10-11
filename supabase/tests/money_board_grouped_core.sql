\set ON_ERROR_STOP on
begin;
set local statement_timeout='8s';
\ir phase7a/fixture.sql
create function pg_temp.cart(a text,cap text,extra jsonb default '{}'::jsonb,req uuid default gen_random_uuid())returns jsonb language sql as $$
 select public.boss_money_board_cart(jsonb_build_object('action',a,'request_id',req,'input',jsonb_build_object('path',pg_temp.fpath('share'))||extra),cap)$$;
grant execute on function pg_temp.cart(text,text,jsonb,uuid)to anon,authenticated;
create function pg_temp.tile(n int)returns uuid language sql security definer set search_path='' as $$select id from public.money_board_tiles where board_id=pg_temp.fid('board')and generation_id=(select id from public.money_board_generations where board_id=pg_temp.fid('board')order by generation desc limit 1)and ordinal=n$$;
grant execute on function pg_temp.tile(int)to anon,authenticated;
create temp table group_results(label text primary key,data jsonb);grant all on group_results to anon,authenticated;
set local role anon;
select pg_temp.check('server cart starts empty','CART',pg_temp.cart('open',repeat('a',64))->>'state'='selection');
select pg_temp.check('add 5','CART',pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(5)))->>'subtotal_minor'='500');
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(10)));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(15)));
select pg_temp.check('aggregate 30 dollars','CART',pg_temp.cart('read',repeat('a',64))->>'subtotal_minor'='3000');
select pg_temp.check('duplicate add is set semantics','CART',jsonb_array_length(pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(5)))->'items')=3);
insert into group_results values('reserve',pg_temp.cart('reserve',repeat('a',64),'{}',pg_temp.f('group-reserve-request')));
select pg_temp.check('group atomically reserved','GROUP',(select data->>'state'='reserved'from group_results where label='reserve'));
select pg_temp.check('safe replay','GROUP',pg_temp.cart('reserve',repeat('a',64),'{}',pg_temp.f('group-reserve-request'))->>'replayed'='true');
select pg_temp.denied('edit held group denied',format('select pg_temp.cart(%L,%L,%L::jsonb)','remove',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(5))),'PT409');
select pg_temp.check('reload recovers same authoritative total','RECOVERY',pg_temp.cart('recover',repeat('a',64))->>'subtotal_minor'='3000');
select pg_temp.check('prepare no provider execution','CHECKOUT',pg_temp.cart('prepare',repeat('a',64),'{"display_name":"Synthetic supporter","anonymous":true}')->>'state'='awaiting_payment');
select pg_temp.check('unpaid gross zero','PROGRESS',public.boss_money_board_public(pg_temp.fpath('share'))->'progress'->>'verified_gross_minor'='0');
select pg_temp.denied('raw guest cart denied','select *from public.money_board_carts','42501');
select pg_temp.denied('browser cannot ingest paid',format('select boss_private.fundraising_ingest_success(%L::uuid,%L,%L,3000,%L,now())',pg_temp.f('fake'),'synthetic','fake','USD'),'42501');
reset role;
select pg_temp.check('three durable single-winner reservations','GROUP',(select count(*)=3 and count(distinct capability_digest)=3 and count(distinct request_id)=3 and count(distinct expires_at)=1 from public.money_board_reservations where tile_id in(pg_temp.tile(5),pg_temp.tile(10),pg_temp.tile(15))));
select pg_temp.check('no recurring commitment created','CHECKOUT',(select count(*)=0 from public.fundraising_recurring_commitments));
select pg_temp.check('one intent and prepared checkout','CHECKOUT',(select count(*)=1 from public.money_board_checkout_preparations));
select pg_temp.check('no live payment source','CHECKOUT',(select count(*)=0 from public.provider_operations)and(select count(*)=0 from public.fundraising_success_evidence));
-- Trusted source owner only, in the disposable rollback transaction.
select boss_private.fundraising_ingest_success(p.intent_id,'disposable_group','group-source',3000,'USD',clock_timestamp())from public.money_board_checkout_preparations p;
select pg_temp.check('one source claims three tiles','SUCCESS',(select count(*)=3 and count(distinct evidence_id)=1 from public.money_board_tile_claims));
select pg_temp.check('aggregate gift qualification once','REWARD',(select count(*)=1 and bool_and(qualified)from public.fundraising_reward_qualifications));
select pg_temp.check('no duplicate campaign progress','PROGRESS',boss_private.fundraising_raised(pg_temp.fid('campaign'))=3000);
set local role anon;
select pg_temp.check('claimed public count','PROGRESS',public.boss_money_board_public(pg_temp.fpath('share'))->'progress'->>'claimed_count'='3');
select pg_temp.check('no private public data','PRIVACY',public.boss_money_board_public(pg_temp.fpath('share'))::text!~'(email|mobile|capability|household|person_id|participant_id)');
reset role;
select pg_temp.check('largest remainder total exact','ROUNDING',(select sum(amount_minor)=101 from boss_private.money_board_allocate_correction((select id from public.fundraising_success_evidence),101)));
select pg_temp.check('largest remainder deterministic','ROUNDING',(select jsonb_agg(to_jsonb(a)order by tie_order)from boss_private.money_board_allocate_correction((select id from public.fundraising_success_evidence),101)a)=(select jsonb_agg(to_jsonb(a)order by tie_order)from boss_private.money_board_allocate_correction((select id from public.fundraising_success_evidence),101)a));
select pg_temp.check('original allocation weights 5 10 15','ROUNDING',(select array_agg(amount_minor order by tie_order)=array[17,34,50]::bigint[]from boss_private.money_board_allocate_correction((select id from public.fundraising_success_evidence),101)));
select pg_temp.check('private helpers closed','ACL',not exists(select 1 from pg_proc p where p.pronamespace='boss_private'::regnamespace and p.proname like'money_board_%'and(has_function_privilege('anon',p.oid,'execute')or has_function_privilege('authenticated',p.oid,'execute')or has_function_privilege('service_role',p.oid,'execute'))));
select pg_temp.check('legacy presentation honors grouped claims','COMPATIBILITY',boss_private.fundraising_board_projection(pg_temp.fid('board'))->>'claimed_count'='3'and boss_private.fundraising_board_projection(pg_temp.fid('board'))->'tiles'->4->>'state'='claimed');
select pg_temp.check('historical gross field not silently reinterpreted','COMPATIBILITY',boss_private.fundraising_board_projection(pg_temp.fid('board'))->>'raised_minor'='0'and boss_private.fundraising_board_projection(pg_temp.fid('board'))->'progress_v2'->>'verified_gross_minor'='3000');
set constraints all immediate;
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
