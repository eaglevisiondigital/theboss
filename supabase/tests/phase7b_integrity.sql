\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7b/fixture.sql
select pg_temp.success('integrity-a',4000);
select pg_temp.success('integrity-b',6000);
set constraints all immediate;set constraints all deferred;
create function pg_temp.invalid_journal(problem text)returns void language plpgsql as $$declare g public.boss_bucks_grants;j uuid;clearing uuid;original uuid;cur text:='USD';begin
 select g1.*into g from public.boss_bucks_grants g1 join public.fundraising_success_evidence e on e.id=g1.evidence_id where e.source_reference='integrity-b';
 select id into original from public.boss_bucks_journals where grant_id=g.id and kind='issuance';
 if problem='original'then select j1.id into original from public.boss_bucks_journals j1 join public.boss_bucks_grants g1 on g1.id=j1.grant_id join public.fundraising_success_evidence e on e.id=g1.evidence_id where e.source_reference='integrity-a';end if;
 if problem='currency'then cur:='CAD';end if;
 if problem='organization'then insert into public.boss_bucks_accounts(kind,organization_id,currency)values('clearing',pg_temp.f('other-org'),'USD')returning id into clearing;
 else select id into clearing from public.boss_bucks_accounts where kind='clearing'and organization_id=g.organization_id and currency='USD';end if;
 insert into public.boss_bucks_journals(grant_id,kind,currency,original_journal_id,reason)values(g.id,case when problem='premature' then 'expiration'else'reversal'end,cur,original,'Invalid synthetic owner-level journal')returning id into j;
 insert into public.boss_bucks_postings(journal_id,account_id,currency,amount_minor)values(j,g.account_id,cur,-g.amount_minor);
 if problem<>'single'then insert into public.boss_bucks_postings(journal_id,account_id,currency,amount_minor)values(j,clearing,cur,case when problem='amount'then g.amount_minor-1 else g.amount_minor end);end if;
 set constraints all immediate;
end$$;
select pg_temp.denied('free-floating single posting denied','select pg_temp.invalid_journal(''single'')','23514');
select pg_temp.denied('unbalanced pair denied','select pg_temp.invalid_journal(''amount'')','23514');
select pg_temp.denied('cross-currency pair denied','select pg_temp.invalid_journal(''currency'')','23514');
select pg_temp.denied('cross-org clearing pair denied','select pg_temp.invalid_journal(''organization'')','23514');
select pg_temp.denied('foreign original journal denied','select pg_temp.invalid_journal(''original'')','23514');
select pg_temp.denied('premature expiration denied','select pg_temp.invalid_journal(''premature'')','23514');
select pg_temp.check('all invalid writes rolled back intact','INTEGRITY',boss_private.bucks_available(pg_temp.w())=5000 and(select count(*)=2 from public.boss_bucks_journals)and(select count(*)=4 from public.boss_bucks_postings));
select count(*)passed_assertions,'Phase 7B integrity' suite from phase5a_assertions;rollback;
