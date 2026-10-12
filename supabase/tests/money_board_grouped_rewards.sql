\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
\ir grouped/cart-helpers.sql
select pg_temp.cart('open',repeat('a',64));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(10)));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(15)));
select pg_temp.cart('reserve',repeat('a',64));select pg_temp.cart('prepare',repeat('a',64),'{"display_name":"Synthetic reward supporter","anonymous":true}');
select pg_temp.check('exact25 exact aggregate principal','REWARD',(select amount_minor=2500 from public.fundraising_intents where provenance->>'channel'='money_board_group'));
insert into group_results values('checkout',boss_private.rails_guest(jsonb_build_object('action','prepare','request_id',gen_random_uuid(),'input',jsonb_build_object('path',pg_temp.fpath('share'),'method','card','capability',encode(sha256(convert_to(repeat('a',64)||':'||(select id from public.money_board_groups),'UTF8')),'hex')))));
select pg_temp.check('existing native payment prepare accepts grouped source','REUSE',(select count(*)=1 from public.payment_checkouts p join public.money_board_checkout_preparations g on g.intent_id=p.intent_id)and(select count(*)=0 from public.provider_operations));
select boss_private.fundraising_ingest_success(intent_id,'disposable-group-reward','exact25',2500,'USD',coalesce((select payment_success_at from public.fundraising_success_evidence e where e.intent_id=p.intent_id),clock_timestamp()))from public.money_board_checkout_preparations p;
select pg_temp.check('exact25 membership source count','REWARD',(select count(*)=0 from public.discount_member_sources s join public.money_board_checkout_preparations p on p.intent_id=s.intent_id where s.kind='supporter_gift'));
set constraints all immediate;select count(*)passed_assertions,'Grouped reward and native prepare' suite from pg_temp.phase5a_assertions;rollback;

\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
\ir grouped/cart-helpers.sql
select pg_temp.actor('admin');select pg_temp.fm('board.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board')),'title','Synthetic grouped threshold','reservation_seconds',600,'visibility','public','start_minor',1,'increment_minor',2499,'tile_count',2,'goal_minor',10000));
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board'))));
select pg_temp.cart('open',repeat('a',64));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(1)));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(2)));
select pg_temp.cart('reserve',repeat('a',64));select pg_temp.cart('prepare',repeat('a',64),'{"display_name":"Synthetic reward supporter","anonymous":true}');
select pg_temp.check('over25 exact aggregate principal','REWARD',(select amount_minor=2501 from public.fundraising_intents where provenance->>'channel'='money_board_group'));
insert into group_results values('checkout',boss_private.rails_guest(jsonb_build_object('action','prepare','request_id',gen_random_uuid(),'input',jsonb_build_object('path',pg_temp.fpath('share'),'method','card','capability',encode(sha256(convert_to(repeat('a',64)||':'||(select id from public.money_board_groups),'UTF8')),'hex')))));
select pg_temp.check('existing native payment prepare accepts grouped source','REUSE',(select count(*)=1 from public.payment_checkouts p join public.money_board_checkout_preparations g on g.intent_id=p.intent_id)and(select count(*)=0 from public.provider_operations));
select boss_private.fundraising_ingest_success(intent_id,'disposable-group-reward','over25',2501,'USD',coalesce((select payment_success_at from public.fundraising_success_evidence e where e.intent_id=p.intent_id),clock_timestamp()))from public.money_board_checkout_preparations p;
select pg_temp.check('over25 membership source count','REWARD',(select count(*)=1 from public.discount_member_sources s join public.money_board_checkout_preparations p on p.intent_id=s.intent_id where s.kind='supporter_gift'));
select boss_private.fundraising_ingest_success(intent_id,'disposable-group-reward','over25',2501,'USD',coalesce((select payment_success_at from public.fundraising_success_evidence e where e.intent_id=p.intent_id),clock_timestamp()))from public.money_board_checkout_preparations p;
select pg_temp.check('aggregate replay never duplicates gift','REPLAY',(select count(*)=1 from public.discount_member_sources s join public.money_board_checkout_preparations p on p.intent_id=s.intent_id where s.kind='supporter_gift'));
insert into public.fundraising_intent_events(intent_id,state,source_reference,amount_minor,remaining_valid_amount_minor)select intent_id,'partially_refunded','SYNTHETIC grouped threshold correction',i.amount_minor-2500,2500 from public.money_board_checkout_preparations p join public.fundraising_intents i on i.id=p.intent_id;
select pg_temp.check('grouped threshold correction revokes gift without deleting history','REWARD_CORRECTION',exists(select 1 from public.discount_member_sources s join public.discount_source_revocations v on v.source_id=s.id join public.money_board_checkout_preparations p on p.intent_id=s.intent_id where s.kind='supporter_gift'and v.reason='gift_reversal'));
select pg_temp.check('gift correction retains every permanent claim','PERMANENCE',(select count(*)=jsonb_array_length(pg_temp.cart('recover',repeat('a',64))->'items')from public.money_board_tile_claims where group_id=(select group_id from public.money_board_checkout_preparations)));
set constraints all immediate;select count(*)passed_assertions,'Grouped reward and native prepare' suite from pg_temp.phase5a_assertions;rollback;

\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
\ir grouped/cart-helpers.sql
select pg_temp.cart('open',repeat('a',64));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(5)));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(10)));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(15)));
select pg_temp.cart('reserve',repeat('a',64));select pg_temp.cart('prepare',repeat('a',64),'{"display_name":"Synthetic reward supporter","anonymous":true}');
select pg_temp.check('aggregate30 exact aggregate principal','REWARD',(select amount_minor=3000 from public.fundraising_intents where provenance->>'channel'='money_board_group'));
insert into group_results values('checkout',boss_private.rails_guest(jsonb_build_object('action','prepare','request_id',gen_random_uuid(),'input',jsonb_build_object('path',pg_temp.fpath('share'),'method','card','capability',encode(sha256(convert_to(repeat('a',64)||':'||(select id from public.money_board_groups),'UTF8')),'hex')))));
select pg_temp.check('existing native payment prepare accepts grouped source','REUSE',(select count(*)=1 from public.payment_checkouts p join public.money_board_checkout_preparations g on g.intent_id=p.intent_id)and(select count(*)=0 from public.provider_operations));
select boss_private.fundraising_ingest_success(intent_id,'disposable-group-reward','aggregate30',3000,'USD',coalesce((select payment_success_at from public.fundraising_success_evidence e where e.intent_id=p.intent_id),clock_timestamp()))from public.money_board_checkout_preparations p;
select pg_temp.check('aggregate30 membership source count','REWARD',(select count(*)=1 from public.discount_member_sources s join public.money_board_checkout_preparations p on p.intent_id=s.intent_id where s.kind='supporter_gift'));
select boss_private.fundraising_ingest_success(intent_id,'disposable-group-reward','aggregate30',3000,'USD',coalesce((select payment_success_at from public.fundraising_success_evidence e where e.intent_id=p.intent_id),clock_timestamp()))from public.money_board_checkout_preparations p;
select pg_temp.check('aggregate replay never duplicates gift','REPLAY',(select count(*)=1 from public.discount_member_sources s join public.money_board_checkout_preparations p on p.intent_id=s.intent_id where s.kind='supporter_gift'));
insert into public.fundraising_intent_events(intent_id,state,source_reference,amount_minor,remaining_valid_amount_minor)select intent_id,'partially_refunded','SYNTHETIC grouped threshold correction',i.amount_minor-2500,2500 from public.money_board_checkout_preparations p join public.fundraising_intents i on i.id=p.intent_id;
select pg_temp.check('grouped threshold correction revokes gift without deleting history','REWARD_CORRECTION',exists(select 1 from public.discount_member_sources s join public.discount_source_revocations v on v.source_id=s.id join public.money_board_checkout_preparations p on p.intent_id=s.intent_id where s.kind='supporter_gift'and v.reason='gift_reversal'));
select pg_temp.check('gift correction retains every permanent claim','PERMANENCE',(select count(*)=jsonb_array_length(pg_temp.cart('recover',repeat('a',64))->'items')from public.money_board_tile_claims where group_id=(select group_id from public.money_board_checkout_preparations)));
set constraints all immediate;select count(*)passed_assertions,'Grouped reward and native prepare' suite from pg_temp.phase5a_assertions;rollback;
