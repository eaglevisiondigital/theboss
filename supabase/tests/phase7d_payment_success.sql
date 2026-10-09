\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7d/fixture.sql
select pg_temp.checkout('authorized');select boss_private.rails_dispatch(pg_temp.f('checkout-authorized'));select pg_temp.receive('authorized','authorized');
select pg_temp.check('authorization creates no canonical payment','CARD',not exists(select 1 from public.payments where method='card'));
select pg_temp.check('authorization creates no contribution','CARD',(select count(*)=1 from public.fundraising_success_evidence));
select pg_temp.receive('authorized','captured');
select pg_temp.check('capture creates canonical payment before settlement','CARD',(select count(*)=1 from public.payments where method='card')and not exists(select 1 from public.provider_event_evidence where kind='settled'));
select pg_temp.check('capture success time is not relabeled settlement','CHRONOLOGY',exists(select 1 from public.fundraising_success_evidence where captured_at is not null and settled_at is null and payment_success_at=captured_at));
select pg_temp.check('capture creates one contribution and earning','DOWNSTREAM',(select count(*)=2 from public.fundraising_success_evidence)and(select count(*)=2 from public.boss_bucks_grants));
select pg_temp.check('capture qualifies frozen reward exactly once','DOWNSTREAM',(select count(*)=2 from public.fundraising_reward_qualifications where qualified));
select pg_temp.receive('authorized','captured');select pg_temp.receive('authorized','settled');
select pg_temp.check('webhook and polling replay create no duplicate payment','IDEMPOTENCY',(select count(*)=1 from public.payments where method='card'));
select pg_temp.check('settlement creates no duplicate contribution or earning','IDEMPOTENCY',(select count(*)=2 from public.fundraising_success_evidence)and(select count(*)=2 from public.boss_bucks_grants));
select pg_temp.checkout('ach-pending','ach',1,true);select boss_private.rails_dispatch(pg_temp.f('checkout-ach-pending'));select pg_temp.receive('ach-pending','ach_pending');
select pg_sleep(0.08);
select pg_temp.check('ACH pending after checkout expiry retains hold','ACH',boss_private.rails_hold(pg_temp.f('checkout-ach-pending')));
select pg_temp.check('ACH pending holds tile unavailable','ACH',boss_private.rails_tile_pending((select tile_id from public.fundraising_intents where request_id=pg_temp.f('intent-ach-pending'))));
select pg_temp.check('pending ACH creates no money, reward or earning','ACH',(select count(*)=0 from public.payments where method='ach')and(select count(*)=2 from public.boss_bucks_grants));
select pg_temp.conflict('pending tile cannot be released',format('update public.money_board_reservations set released_at=clock_timestamp(),release_reason=''expired''where id=(select reservation_id from public.fundraising_intents where request_id=%L)',pg_temp.f('intent-ach-pending')));
select pg_temp.receive('ach-pending','settled');select pg_temp.receive('ach-pending','settled');
select pg_temp.check('delayed final ACH creates one canonical success','ACH',(select count(*)=1 from public.payments where method='ach')and(select count(*)=3 from public.fundraising_success_evidence));
select pg_temp.check('delayed ACH permanently claims original tile','ACH',exists(select 1 from public.fundraising_success_evidence e join public.fundraising_intents i on i.id=e.intent_id where i.request_id=pg_temp.f('intent-ach-pending')and e.tile_id=i.tile_id));
select pg_temp.checkout('ach-failure','ach',2,true);select boss_private.rails_dispatch(pg_temp.f('checkout-ach-failure'));select pg_temp.receive('ach-failure','ach_pending');select pg_sleep(0.08);select pg_temp.receive('ach-failure','failed');
select pg_temp.check('definitive ACH failure releases hold','ACH',not boss_private.rails_hold(pg_temp.f('checkout-ach-failure')));
select pg_temp.check('definitive failure explicitly releases reservation','ACH',exists(select 1 from public.money_board_reservations r join public.fundraising_intents i on i.reservation_id=r.id where i.request_id=pg_temp.f('intent-ach-failure')and r.released_at is not null));
select pg_temp.checkout('unknown','card',3,true);select boss_private.rails_dispatch(pg_temp.f('checkout-unknown'));select pg_temp.receive('unknown','unknown');select pg_sleep(0.08);
select pg_temp.check('unknown preserves pending hold','UNKNOWN',boss_private.rails_hold(pg_temp.f('checkout-unknown')));
insert into payment_results values('redispatch',boss_private.rails_dispatch(pg_temp.f('checkout-unknown')));
select pg_temp.check('unknown retry retains same operation, never re-executes','UNKNOWN',(select result->'first_dispatch'='false'::jsonb from payment_results where label='redispatch')and(select count(*)=1 from public.provider_operations where checkout_id=pg_temp.f('checkout-unknown')));
select pg_temp.receive('unknown','captured');select pg_temp.receive('unknown','captured');
select pg_temp.check('unknown original success completes once','UNKNOWN',(select count(*)=1 from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-unknown')));
select pg_temp.checkout('unknown-failure','card',4,true);select boss_private.rails_dispatch(pg_temp.f('checkout-unknown-failure'));select pg_temp.receive('unknown-failure','unknown');select pg_sleep(0.08);select pg_temp.receive('unknown-failure','failed');
select pg_temp.check('unknown definitive failure releases resource','UNKNOWN',not boss_private.rails_hold(pg_temp.f('checkout-unknown-failure')));
select pg_temp.checkout('canceled','card',5);select boss_private.rails_dispatch(pg_temp.f('checkout-canceled'));
select boss_private.rails_invalidate(pg_temp.f('checkout-canceled'),'reviewed_cancel',null,pg_temp.f('admin'));select pg_temp.receive('canceled','captured');
select pg_temp.check('explicitly canceled late success is canonical unallocated review','LATE_SUCCESS',(select state='captured_unallocated'from public.payment_checkouts where id=pg_temp.f('checkout-canceled'))and exists(select 1 from public.payment_review_cases where checkout_id=pg_temp.f('checkout-canceled')and reason='late_success'));
select pg_temp.check('explicitly canceled late success has no contribution or earning','LATE_SUCCESS',not exists(select 1 from public.fundraising_success_evidence e join public.fundraising_intents i on i.id=e.intent_id where i.request_id=pg_temp.f('intent-canceled')));
select pg_temp.checkout('contradiction','card',2);select boss_private.rails_dispatch(pg_temp.f('checkout-contradiction'));select pg_temp.receive('contradiction','captured');
select pg_temp.receive('ach-failure','captured');
select pg_temp.check('ACH capture alone cannot claim another tile','METHOD',(select count(*)=1 from public.fundraising_success_evidence where tile_id=(select tile_id from public.fundraising_intents where request_id=pg_temp.f('intent-contradiction'))));
select pg_temp.receive('ach-failure','settled');
select pg_temp.check('contradictory success after released and reassigned tile goes to review','LATE_SUCCESS',(select state='captured_unallocated'from public.payment_checkouts where id=pg_temp.f('checkout-ach-failure')));
select pg_temp.check('one tile never gains two legitimate claimants','TILE',not exists(select tile_id from public.fundraising_success_evidence where tile_id is not null group by tile_id having count(*)>1));
-- Expire the original intent and tile clocks, not only the shorter checkout.
-- Insert bounded synthetic originals; immutable historical rows are not edited.
do $$declare x public.fundraising_intents;r uuid;tile uuid;cap text:=repeat('e',64);ts timestamptz:=clock_timestamp();begin
 select *into x from public.fundraising_intents where request_id=pg_temp.f('intent-authorized');
 select id into tile from public.money_board_tiles where board_id=pg_temp.fid('board')and ordinal=12;
 insert into public.money_board_reservations(tile_id,capability_digest,starts_at,expires_at,request_id)values(tile,cap,ts,ts+interval'500 milliseconds',pg_temp.f('original-short-reservation'))returning id into r;
 insert into public.fundraising_intents(id,campaign_id,fundraiser_id,donor_id,board_id,tile_id,reservation_id,share_id,amount_minor,currency,anonymous,fee_cover,source_kind,provenance,reward_policy,capability_digest,expires_at,request_id)
 values(pg_temp.f('original-short-intent'),x.campaign_id,x.fundraiser_id,x.donor_id,pg_temp.fid('board'),tile,r,x.share_id,(select amount_minor from public.money_board_tiles where id=tile),x.currency,true,false,x.source_kind,x.provenance,x.reward_policy,cap,ts+interval'500 milliseconds',pg_temp.f('original-short-intent-request'));
 insert into public.fundraising_intent_events(intent_id,state)values(pg_temp.f('original-short-intent'),'awaiting_payment');
 insert into public.payment_checkouts(id,organization_id,intent_id,purpose,currency,account_id,routing_id,policy_id,method,principal_minor,external_minor,request_id,command_hash,capability_digest,expires_at)
 values(pg_temp.f('checkout-original-short'),pg_temp.f('org'),pg_temp.f('original-short-intent'),'fundraising','USD',pg_temp.f('rails-account'),pg_temp.f('fundraising-route'),pg_temp.f('settlement-policy'),'ach',(select amount_minor from public.money_board_tiles where id=tile),(select amount_minor from public.money_board_tiles where id=tile),pg_temp.f('original-short-checkout-request'),repeat('f',64),cap,ts+interval'400 milliseconds');
 perform boss_private.rails_dispatch(pg_temp.f('checkout-original-short'));end$$;
select pg_temp.receive('original-short','ach_pending');select pg_sleep(0.6);
select pg_temp.check('original tile and intent clocks really elapsed','CLOCK',exists(select 1 from public.fundraising_intents i join public.money_board_reservations r on r.id=i.reservation_id where i.id=pg_temp.f('original-short-intent')and i.expires_at<clock_timestamp()and r.expires_at<clock_timestamp()));
select pg_temp.check('provider pending supersedes original tile expiry','CLOCK',boss_private.rails_tile_pending((select tile_id from public.fundraising_intents where id=pg_temp.f('original-short-intent'))));
select pg_temp.receive('original-short','settled');select pg_temp.receive('original-short','settled');
select pg_temp.check('original expired reservation accepts committed ACH once','CLOCK',(select count(*)=1 from public.fundraising_success_evidence where intent_id=pg_temp.f('original-short-intent')));

select pg_temp.checkout('natural-end','ach');select boss_private.rails_dispatch(pg_temp.f('checkout-natural-end'));select pg_temp.receive('natural-end','ach_pending');
insert into public.settlement_policy_revisions(organization_id,purpose,currency,revision,organization_basis_points,platform_basis_points,product_cost_basis_points,processor_fee_owner,availability_seconds,created_by)
values(pg_temp.f('org'),'fundraising','USD',2,6000,4000,0,'platform',120,pg_temp.f('admin'));
set local role authenticated;select pg_temp.actor('admin');select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',1000,'currency','USD','channels',jsonb_build_array('direct_support','money_board')));reset role;
update public.fundraising_campaigns set ends_at=clock_timestamp()+interval'40 milliseconds' where id=pg_temp.fid('campaign');select pg_sleep(0.06);
select pg_temp.receive('natural-end','settled');
select pg_temp.check('committed ACH success survives natural campaign end','NATURAL_EXPIRY',(select state='completed'from public.payment_checkouts where id=pg_temp.f('checkout-natural-end')));
select pg_temp.check('original frozen settlement revision retained','SNAPSHOT',(select snapshot->>'settlement_policy_revision_id'=pg_temp.f('settlement-policy')::text from public.payment_eligibility_commits where checkout_id=pg_temp.f('checkout-natural-end')));
select pg_temp.check('delayed earning uses original revision and rate','SNAPSHOT',exists(select 1 from public.boss_bucks_grants g join public.fundraising_intents i on i.id=g.intent_id where i.request_id=pg_temp.f('intent-natural-end')and g.amount_minor=5000));
select pg_temp.denied('new attempts after natural campaign end denied','select pg_temp.checkout(''after-end'')','PT404');
select pg_temp.denied('eligibility history cannot be rewritten',format('update public.payment_eligibility_commits set snapshot=''{}''where checkout_id=%L',pg_temp.f('checkout-natural-end')),'23514');

set constraints all immediate;
select count(*)passed_assertions,'Phase 7D method success and pending holds' suite from phase5a_assertions;rollback;
