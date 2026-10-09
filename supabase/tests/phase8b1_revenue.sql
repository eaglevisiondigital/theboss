\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8b1/fixture.sql
set local role authenticated;
select pg_temp.pm('policy','policy.create',pg_temp.pi(jsonb_build_object('contract_id',pg_temp.pid('contract'),'currency','USD','basis','percentage','rate_ppm',100000,'recognition_condition','fulfilled','starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'10 days')));
select pg_temp.pm('tx','transaction.create',pg_temp.pi(jsonb_build_object('external_id','synthetic-transaction','revision_id',pg_temp.pid('benefit'),'policy_id',pg_temp.pid('policy'),'currency','USD','eligible_minor',10000,'synthetic',true,'occurred_at',clock_timestamp(),'evidence_reference','synthetic-evidence/transaction')));
select pg_temp.pm('click','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','click','kind','referred','evidence_reference','synthetic-evidence/click')));reset role;
select pg_temp.check('click is not earned commission','REVENUE',boss_private.partner_commission_evidence(pg_temp.pid('tx'))->'estimated_minor'='null'::jsonb);
set local role authenticated;
select pg_temp.denied('confirmation without booking request denied',format('select pg_temp.pm(''early'',''transaction.event'',%L)',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','early','kind','confirmed','evidence_reference','synthetic-evidence/early'))),'PT409');
select pg_temp.pm('request','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','request','kind','requested','evidence_reference','synthetic-evidence/request')));
select pg_temp.pm('confirm','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','confirm','kind','confirmed','evidence_reference','synthetic-evidence/confirm')));reset role;
select pg_temp.check('booking confirmation not fulfillment','REVENUE',boss_private.partner_commission_evidence(pg_temp.pid('tx'))->'estimated_minor'='null'::jsonb);
set local role authenticated;
select pg_temp.pm('fulfill','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','fulfill','kind','fulfilled','evidence_reference','synthetic-evidence/fulfill')));reset role;
select pg_temp.check('precise percentage synthetic estimate','REVENUE',(boss_private.partner_commission_evidence(pg_temp.pid('tx'))->>'estimated_minor')::bigint=1000);
select pg_temp.check('no actual revenue recognition','SEPARATION',boss_private.partner_commission_evidence(pg_temp.pid('tx'))->'earned_revenue'='false'::jsonb);
select pg_temp.check('no settlement execution','SEPARATION',boss_private.partner_commission_evidence(pg_temp.pid('tx'))->'settlement_executed'='false'::jsonb);
set local role authenticated;
select pg_temp.pm('refund','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','refund','kind','refund','adjustment_minor',2500,'evidence_reference','synthetic-evidence/refund')));reset role;
select pg_temp.check('partial cancellation estimate reduced','REVENUE',(boss_private.partner_commission_evidence(pg_temp.pid('tx'))->>'estimated_minor')::bigint=750);
set local role authenticated;
select pg_temp.pm('correction','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','correction','kind','correction','corrects_event_id',pg_temp.pid('refund'),'evidence_reference','synthetic-evidence/correction')));reset role;
select pg_temp.check('immutable correction preserves refund evidence','REVENUE',(select count(*)=1 from public.partner_transaction_events where id=pg_temp.pid('refund')));
select pg_temp.check('correction reprojects exact synthetic estimate','REVENUE',(boss_private.partner_commission_evidence(pg_temp.pid('tx'))->>'estimated_minor')::bigint=1000);
set local role authenticated;
select pg_temp.denied('duplicate correction denied',format('select pg_temp.pm(''double-correction'',''transaction.event'',%L)',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','double-correction','kind','correction','corrects_event_id',pg_temp.pid('refund'),'evidence_reference','synthetic-evidence/correction'))),'PT409');
select pg_temp.denied('cross currency rejected',format('select pg_temp.pm(''cross-currency'',''transaction.create'',%L)',pg_temp.pi(jsonb_build_object('external_id','cross-currency','revision_id',pg_temp.pid('benefit'),'policy_id',pg_temp.pid('policy'),'currency','CAD','eligible_minor',10000,'synthetic',true,'occurred_at',clock_timestamp(),'evidence_reference','synthetic-evidence/transaction'))),'PT422');
select pg_temp.denied('duplicate external transaction rejected',format('select pg_temp.pm(''duplicate-tx'',''transaction.create'',%L)',pg_temp.pi(jsonb_build_object('external_id','synthetic-transaction','revision_id',pg_temp.pid('benefit'),'policy_id',pg_temp.pid('policy'),'currency','USD','eligible_minor',10000,'synthetic',true,'occurred_at',clock_timestamp(),'evidence_reference','synthetic-evidence/transaction'))),'PT409');
select pg_temp.denied('expired commercial source rejected',format('select pg_temp.pm(''expired-tx'',''transaction.create'',%L)',pg_temp.pi(jsonb_build_object('external_id','expired-source','revision_id',pg_temp.pid('benefit'),'policy_id',pg_temp.pid('policy'),'currency','USD','eligible_minor',10000,'synthetic',true,'occurred_at',clock_timestamp()+interval'30 days','evidence_reference','synthetic-evidence/transaction'))),'PT422');
reset role;
select pg_temp.denied('source immutable','update public.partner_transaction_sources set eligible_minor=1','23514');
select pg_temp.denied('commercial policy immutable','update public.partner_commission_policies set rate_ppm=999999','23514');
set local role authenticated;select pg_temp.actor('admin');
do $$declare basis text;p jsonb;r jsonb;begin
 foreach basis in array array['fixed','zero','unknown']loop
 p:=jsonb_build_object('contract_id',pg_temp.pid('contract'),'currency','USD','basis',basis,'recognition_condition','confirmed','starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'10 days');
 if basis='fixed'then p:=p||'{"fixed_minor":750}'::jsonb;end if;
 perform pg_temp.pm('p-'||basis,'policy.create',pg_temp.pi(p));
 perform pg_temp.pm('t-'||basis,'transaction.create',pg_temp.pi(jsonb_build_object('external_id','synthetic-'||basis,'revision_id',pg_temp.pid('benefit'),'policy_id',pg_temp.pid('p-'||basis),'currency','USD','eligible_minor',10000,'synthetic',true,'occurred_at',clock_timestamp(),'evidence_reference','synthetic-evidence/'||basis)));
 perform pg_temp.pm('req-'||basis,'transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('t-'||basis),'external_event_id','request-'||basis,'kind','requested','evidence_reference','synthetic-evidence/'||basis)));
 perform pg_temp.pm('confirm-'||basis,'transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('t-'||basis),'external_event_id','confirm-'||basis,'kind','confirmed','evidence_reference','synthetic-evidence/'||basis)));
 select v into r from jsonb_array_elements(public.boss_partners_read(pg_temp.pi('{"mode":"revenue"}'))->'transactions')v where v->>'transaction_id'=pg_temp.pid('t-'||basis)::text;
 perform pg_temp.check(basis||' SQL evidence estimate','REVENUE',r->'estimated_minor'=case basis when'fixed'then'750'::jsonb when'zero'then'0'::jsonb else'null'::jsonb end);
 perform pg_temp.check(basis||' SQL evidence never posts earned revenue','SEPARATION',r->'earned_revenue'='false'::jsonb and r->'settlement_executed'='false'::jsonb);
 end loop;
end$$;reset role;
set constraints all immediate;
select count(*)passed_assertions,'Phase 8B1 separate financial evidence'::text suite from phase5a_assertions;rollback;
