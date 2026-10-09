-- Independent rollback-only $80 invalid-source/recovery fixture.
\ir fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support')));reset role;
select pg_temp.success('release-original-A',8000);
set local role authenticated;select pg_temp.actor('parent');
insert into payment_results values('original-A',pg_temp.bm('payment.spend',pg_temp.spend_input(8000)));reset role;
create temp table release_case as select t.payment_id,a.id allocation_id,g.id grant_id,c.id claim_id from public.boss_bucks_tenders t
 join public.payment_allocations a on a.payment_id=t.payment_id join public.boss_bucks_consumptions bc on bc.allocation_id=a.id
 join public.boss_bucks_grants g on g.id=bc.grant_id left join public.boss_bucks_recovery_claims c on c.grant_id=g.id;
select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='release-original-A'),'Synthetic original source invalidation');
update release_case set claim_id=(select id from public.boss_bucks_recovery_claims where grant_id=release_case.grant_id);
grant select on release_case to authenticated;
create function pg_temp.return_input(amount bigint)returns jsonb language sql as $$select jsonb_build_object('payment_id',payment_id,'reason','Synthetic covered-recovery payment return',
 'allocations',jsonb_build_array(jsonb_build_object('allocation_id',allocation_id,'amount_minor',amount)))from release_case$$;
grant execute on function pg_temp.return_input(bigint)to authenticated;
create function pg_temp.source_grant(label text)returns uuid language sql as $$select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference=$1$$;
create function pg_temp.verify_release()returns void language plpgsql as $$begin
 perform pg_temp.check('original invalid source remains invalid','SOURCE',boss_private.bucks_entitlement((select grant_id from release_case))=0 and boss_private.bucks_grant_book((select grant_id from release_case))=0);
 perform pg_temp.check('recovery account rebuild equals explicit outstanding claims','REBUILD',coalesce((select sum(p.amount_minor)from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where a.kind='recovery'and a.wallet_id=pg_temp.w()and a.organization_id=pg_temp.f('org')),0)=-boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org')));
 perform pg_temp.check('household ledger rebuild equals current available value','REBUILD',coalesce((select sum(p.amount_minor)from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where a.kind='household'and a.wallet_id=pg_temp.w()and a.organization_id=pg_temp.f('org')),0)=boss_private.bucks_available(pg_temp.w(),pg_temp.f('org')));
 perform pg_temp.check('release journals balanced and original lineage retained','LEDGER',not exists(select journal_id from public.boss_bucks_postings group by journal_id having count(*)<>2 or sum(amount_minor)<>0)and not exists(select 1 from public.boss_bucks_recovery_movements r join public.boss_bucks_recovery_movements a on a.id=r.original_movement_id where r.kind='release'and(a.kind<>'apply'or a.replacement_grant_id<>r.replacement_grant_id or a.claim_id<>r.claim_id)));
 perform pg_temp.check('released value no longer simultaneously satisfies recovery','VALUE',not exists(select 1 from public.boss_bucks_grants g where boss_private.bucks_grant_book(g.id)>greatest(boss_private.bucks_entitlement(g.id)-boss_private.bucks_net_use(g.id),0)));
 perform pg_temp.check('safe recovery release audit identifies original movement and payment return','AUDIT',(select count(*)from public.boss_bucks_recovery_movements where kind='release')=(select count(*)from public.boss_bucks_history where action='boss_bucks.recovery.release'));
end$$;
set constraints all immediate;set constraints all deferred;
select pg_temp.check('$80 original payment was recorded','PAYMENT',(select amount_minor=8000 and status='recorded'from public.payments where id=(select payment_id from release_case)));
select pg_temp.check('$80 invalid source creates explicit recovery without rewriting charge','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=8000 and boss_private.bucks_available(pg_temp.w())=0 and boss_private.registration_charge_balance(pg_temp.f('charge-camp'))->>'balance_due_minor'='2000');
