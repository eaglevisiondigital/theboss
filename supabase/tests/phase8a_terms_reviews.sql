\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8a/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.mo('fixed','{"offer_type":"fixed_amount_off","discount_bps":null,"amount_minor":500,"currency":"USD","qualification":"minimum_amount","minimum_minor":2500}');
select pg_temp.mo('bogo','{"offer_type":"bogo","discount_bps":10000,"buy_quantity":2,"benefit_quantity":1,"purchase_description":"Reviewed qualifying synthetic items","benefit_description":"One synthetic item","qualification":"item","qualifying_description":"Synthetic qualifying category"}');
select pg_temp.mo('free','{"offer_type":"free_item","discount_bps":null,"benefit_quantity":1,"benefit_description":"Synthetic complimentary item","exclusions":"Tax and gratuity excluded","stacking":"reviewed_policy","stacking_policy":"Reviewed merchant-only promotions"}');
select pg_temp.check('immutable new revisions start draft','REVIEW',(public.boss_merchants_read(pg_temp.mi('{"mode":"portal"}'))->'offers')::text like'%draft%');
select pg_temp.denied('cannot publish draft without submission',format('select pg_temp.mm(''draft-approval'',''offer.status'',%L)',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('fixed'),'state','published','reason','Synthetic reviewed fixed offer'))),'PT409');
select pg_temp.actor('parent');select pg_temp.mm('fixed-submit','offer.status',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('fixed'),'state','pending_review')));
select pg_temp.denied('owner cannot review economic change',format('select pg_temp.mm(''owner-approve'',''offer.status'',%L)',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('fixed'),'state','published','reason','Self approval attempted'))));
select pg_temp.actor('admin');select pg_temp.mm('fixed-approve','offer.status',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('fixed'),'state','published','reason','Independently reviewed configured economics')));
reset role;
select pg_temp.check('approval archives old current revision','VERSION',boss_private.merchant_offer_state(pg_temp.mid('offer'))='archived');
select pg_temp.check('revision publication immutable terms','TERMS',(select amount_minor=500 and minimum_minor=2500 and currency='USD'from public.merchant_offer_revisions where id=pg_temp.mid('fixed')));
select pg_temp.check('BOGO preserves required quantities','TERMS',(select buy_quantity=2 and benefit_quantity=1 and discount_bps=10000 from public.merchant_offer_revisions where id=pg_temp.mid('bogo')));
select pg_temp.check('free item has reviewed policy','TERMS',(select benefit_quantity=1 and stacking='reviewed_policy'and stacking_policy is not null from public.merchant_offer_revisions where id=pg_temp.mid('free')));
select pg_temp.check('all revisions share allowance identity','USAGE',(select count(distinct family_id)=1 from public.merchant_offer_revisions));
select pg_temp.check('revision cannot reset usage policy','USAGE',(select usage_limit=2 and reset_period='lifetime'from public.merchant_offer_families where id=pg_temp.mid('family')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.mm('review-other','merchant.review',jsonb_build_object('merchant_id',pg_temp.mid('merchant-other','merchant_id'),'state','active','reason','Reviewed valid listing only merchant'));
select pg_temp.mm('other-loc','location.create',jsonb_build_object('merchant_id',pg_temp.mid('merchant-other','merchant_id'),'market_id',pg_temp.mid('market','market_id'),'name','SYNTHETIC listing only location','address','6 Synthetic Street','city','Synthetic City','postal_code','00000','timezone','UTC'));
reset role;set local role anon;
select pg_temp.check('active listing only needs no offers','LISTING_ONLY',jsonb_array_length(public.boss_merchants_directory(jsonb_build_object('market_id',pg_temp.mid('market','market_id')))->'items')=2);
select pg_temp.denied('national substring scan query rejected','select public.boss_merchants_directory(''{"search":"%test%"}'')','PT422');
select pg_temp.denied('bounded directory max50','select public.boss_merchants_directory(''{"limit":51}'')','PT422');
select pg_temp.denied('anonymous member detail RPC closed','select public.boss_merchants_read(''{}'')','42501');
reset role;set constraints all immediate;
select count(*)passed_assertions,'Phase 8A structured terms review revisioning and listing only'::text suite from phase5a_assertions;rollback;
