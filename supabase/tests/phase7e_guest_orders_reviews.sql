\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
grant all on discount_test_results to anon;
create function pg_temp.guest(label text,action text,input jsonb)returns void language plpgsql as $$declare result jsonb;begin
 if action in('product.prepare','product.status')then result:=public.boss_payments_support(jsonb_build_object('action',action,'request_id',pg_temp.f(label),'input',input));
 else result:=public.boss_discounts_support(jsonb_build_object('action',action,'request_id',pg_temp.f(label),'input',input));end if;
 insert into discount_test_results values(label,result)on conflict on constraint discount_test_results_pkey do update set result=excluded.result;
end$$;
grant execute on function pg_temp.guest(text,text,jsonb)to anon;
insert into fundraising_ids select 'alternate-share',id,public_path from public.money_boards where id=pg_temp.fid('board');
set local role anon;
select pg_temp.denied('SQL delivery input cannot carry arbitrary private fields',format('select pg_temp.guest(''invalid-address'',''product.prepare'',%L)',jsonb_build_object('path',pg_temp.fpath('share'),'organization_id',pg_temp.f('org'),'revision_id',pg_temp.did('base30','revision_id'),'quantity',1,'method','card','capability',repeat('a',64),'address',jsonb_build_object('auth_token','synthetic-invalid'))),'PT422');
select pg_temp.denied('SQL delivery input rejects oversized contact',format('select pg_temp.guest(''invalid-email'',''product.prepare'',%L)',jsonb_build_object('path',pg_temp.fpath('share'),'organization_id',pg_temp.f('org'),'revision_id',pg_temp.did('base30','revision_id'),'quantity',1,'method','card','capability',repeat('a',64),'email',repeat('a',255))),'PT422');
select pg_temp.guest('guest-order','product.prepare',jsonb_build_object('path',pg_temp.fpath('share'),'organization_id',pg_temp.f('org'),'revision_id',pg_temp.did('base30','revision_id'),'quantity',1,'method','card','capability',repeat('f',64)));
select pg_temp.guest('guest-order','product.prepare',jsonb_build_object('path',pg_temp.fpath('share'),'organization_id',pg_temp.f('org'),'revision_id',pg_temp.did('base30','revision_id'),'quantity',1,'method','card','capability',repeat('f',64)));
select pg_temp.check('guest purchase retry keeps one original attempt','REPLAY',pg_temp.dr('guest-order')->'replayed'='true'::jsonb);
select pg_temp.denied('private receipt requires exact original share context',format('select pg_temp.guest(''forged-status'',''product.status'',%L)',jsonb_build_object('path',pg_temp.fpath('alternate-share'),'capability',repeat('f',64))),'PT404');
select pg_temp.denied('receipt requires original private proof',format('select pg_temp.guest(''forged-proof'',''product.status'',%L)',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('e',64))),'PT404');
reset role;
select boss_private.rails_dispatch(pg_temp.did('guest-order','checkout_id'));select pg_temp.product_receive('guest-order','captured');
select pg_temp.check('guest payment stays unclaimed and creates no guessed person','IDENTITY',exists(select 1 from public.discount_orders where id=pg_temp.did('guest-order','order_id')and buyer_person_id is null and subject_id is null)and not exists(select 1 from public.discount_memberships where subject_id is not null));
set local role anon;
select pg_temp.guest('guest-status','product.status',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('f',64)));
select pg_temp.guest('guest-paid-claim','product.claim',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('f',64),'item_id',pg_temp.dr('guest-status')->'items'->0->>'item_id'));
select pg_temp.check('paid guest gets concealed one-time claim handoff','CLAIM',length(pg_temp.dr('guest-paid-claim')->>'claim_secret')=64);
select pg_temp.guest('guest-paid-replay','product.claim',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('f',64),'item_id',pg_temp.dr('guest-status')->'items'->0->>'item_id'));
-- A fresh issuance revokes the previous pending proof; it never exposes the
-- previous code or assigns a Boss identity from guest contact information.
reset role;set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('superseded private claim cannot activate',format('select pg_temp.dm(''obsolete-claim'',''membership.claim'',%L)',jsonb_build_object('claim_secret',pg_temp.dr('guest-paid-claim')->>'claim_secret')),'PT404');
select pg_temp.dm('consumer-claim','membership.claim',jsonb_build_object('claim_secret',pg_temp.dr('guest-paid-replay')->>'claim_secret'));
select pg_temp.check('guest explicitly claims to persistent signed person','IDENTITY',(public.boss_discounts_read(jsonb_build_object('membership_id',pg_temp.did('consumer-claim')))->'memberships'->0->'effective'->>'source')='fundraising_product_sale');
reset role;
select pg_temp.check('paid claims never create a Wallet grant','SEPARATION',(select count(*)=1 from public.boss_bucks_grants));
select pg_temp.check('normal receipt and private stored results contain no raw code','PRIVACY',not exists(select 1 from boss_private.discount_guest_claim_requests where result::text like'%'||(pg_temp.dr('guest-paid-replay')->>'claim_secret')||'%')and not(pg_temp.dr('guest-status')?|array['email','address','person_id','membership_id','claim_secret']));
-- Shared provider evidence with no exact original-item mapping is held for
-- review before a guessed financial allocation or benefit reversal can occur.
select pg_temp.product_receive('guest-order','disputed');
select boss_private.rails_external_correct(t.payment_id,e.id,'chargeback',1)from public.external_payment_tenders t join public.provider_event_evidence e on e.event_reference='guest-order-disputed'where t.checkout_id=pg_temp.did('guest-order','checkout_id')and t.original_payment_id is null;
select pg_temp.check('unmapped partial dispute creates explicit review','REVIEW',(select state='review'from public.discount_orders where id=pg_temp.did('guest-order','order_id'))and exists(select 1 from public.payment_review_cases where checkout_id=pg_temp.did('guest-order','checkout_id')));
select pg_temp.check('ambiguous correction never guesses canonical allocation','REVIEW',not exists(select 1 from public.external_payment_corrections where original_payment_id=(select payment_id from public.discount_orders where id=pg_temp.did('guest-order','order_id'))));
select pg_temp.check('review holds membership benefit and payable source','REVIEW',(boss_private.discount_effective(pg_temp.did('consumer-claim'))->>'available')='false'and boss_private.rails_source_payable((select payment_id from public.discount_orders where id=pg_temp.did('guest-order','order_id')))=0);
select pg_temp.check('review holds fundraising credit without rewriting history','REVIEW',boss_private.fundraising_raised(pg_temp.fid('campaign'),pg_temp.fid('fundraiser'))=10000 and(select sum(amount_minor)=1750 from public.discount_product_credits));
set local role anon;
select pg_temp.denied('review cannot issue another paid claim',format('select pg_temp.guest(''review-claim'',''product.claim'',%L)',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('f',64),'item_id',pg_temp.dr('guest-status')->'items'->0->>'item_id')),'PT404');
reset role;
-- A code issued before a review hold does not retain activation authority.
set local role anon;
select pg_temp.guest('pending-review-order','product.prepare',jsonb_build_object('path',pg_temp.fpath('share'),'organization_id',pg_temp.f('org'),'revision_id',pg_temp.did('base30','revision_id'),'quantity',1,'method','card','capability',repeat('c',64)));
reset role;
select boss_private.rails_dispatch(pg_temp.did('pending-review-order','checkout_id'));select pg_temp.product_receive('pending-review-order','captured');
set local role anon;
select pg_temp.guest('pending-review-status','product.status',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('c',64)));
select pg_temp.guest('pending-review-code','product.claim',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('c',64),'item_id',pg_temp.dr('pending-review-status')->'items'->0->>'item_id'));
reset role;
select pg_temp.product_receive('pending-review-order','disputed');
select boss_private.rails_external_correct(t.payment_id,e.id,'chargeback',1)from public.external_payment_tenders t join public.provider_event_evidence e on e.event_reference='pending-review-order-disputed'where t.checkout_id=pg_temp.did('pending-review-order','checkout_id')and t.original_payment_id is null;
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('preissued private code cannot claim a reviewed order',format('select pg_temp.dm(''held-old-code'',''membership.claim'',%L)',jsonb_build_object('claim_secret',pg_temp.dr('pending-review-code')->>'claim_secret')),'PT404');
reset role;
update public.organization_modules set configuration=configuration||'{"membership_sales":false}'::jsonb where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='boss_bucks');
set local role anon;
select pg_temp.conflict('guest order replay cannot retain disabled sales authority',format('select pg_temp.guest(''guest-order'',''product.prepare'',%L)',jsonb_build_object('path',pg_temp.fpath('share'),'organization_id',pg_temp.f('org'),'revision_id',pg_temp.did('base30','revision_id'),'quantity',1,'method','card','capability',repeat('f',64))));
reset role;set constraints all immediate;
select count(*)passed_assertions,'Phase 7E guest purchase privacy and original-item review'::text suite from phase5a_assertions;rollback;
