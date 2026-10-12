\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/fixture.sql
select pg_temp.success('integrity-source',2000);
create function pg_temp.orphan_payment()returns void language plpgsql as $$begin
 insert into public.payments(organization_id,method,amount_minor,currency,payer_person_id,received_at,recorded_by_person_id)
 values(pg_temp.f('org'),'boss_bucks',1,'USD',pg_temp.f('parent'),clock_timestamp(),pg_temp.f('parent'));
 set constraints all immediate;
end$$;
select pg_temp.denied('orphan canonical internal payment cannot commit','select pg_temp.orphan_payment()','23514');
create function pg_temp.orphan_debit()returns void language plpgsql as $$begin
 perform boss_private.bucks_pair((select id from public.boss_bucks_grants limit 1),'spend',1,'Synthetic orphan debit');set constraints all immediate;
end$$;
select pg_temp.denied('orphan wallet debit cannot commit','select pg_temp.orphan_debit()','23514');
create function pg_temp.orphan_restore()returns void language plpgsql as $$begin
 perform boss_private.bucks_pair((select id from public.boss_bucks_grants limit 1),'payment_restore',1,'Synthetic free credit');set constraints all immediate;
end$$;
select pg_temp.denied('unbacked restoration cannot commit','select pg_temp.orphan_restore()','23514');
create function pg_temp.orphan_recovery()returns void language plpgsql as $$begin
 perform boss_private.bucks_pair((select id from public.boss_bucks_grants limit 1),'recovery_open',1,'Synthetic unbacked recovery');set constraints all immediate;
end$$;
select pg_temp.denied('unbacked recovery cannot commit','select pg_temp.orphan_recovery()','23514');
create function pg_temp.false_entitlement()returns void language plpgsql as $$begin
 insert into public.boss_bucks_source_corrections(grant_id,source_key,remaining_source_minor,entitlement_minor)
 values((select id from public.boss_bucks_grants limit 1),'synthetic-bad-floor',1000,999);set constraints all immediate;
end$$;
select pg_temp.denied('incorrect captured-policy floor cannot commit','select pg_temp.false_entitlement()','23514');
create function pg_temp.unposted_loss()returns void language plpgsql as $$begin
 insert into public.boss_bucks_source_corrections(grant_id,source_key,remaining_source_minor,entitlement_minor)
 values((select id from public.boss_bucks_grants limit 1),'synthetic-unposted-loss',0,0);set constraints all immediate;
end$$;
select pg_temp.denied('source loss cannot silently alter a display balance','select pg_temp.unposted_loss()','23514');
select pg_temp.check('all failed forged owner writes rollback','ATOMICITY',boss_private.bucks_available(pg_temp.w())=1000 and(select count(*)=1 from public.boss_bucks_journals)and not exists(select 1 from public.payments));
set local role authenticated;select pg_temp.actor('parent');
insert into payment_results values('good',pg_temp.bm('payment.spend',pg_temp.spend_input(100)));
reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.denied('canonical internal payment immutable','update public.payments set amount_minor=99','PT409');
select pg_temp.denied('canonical allocation immutable','delete from public.payment_allocations','PT409');
select pg_temp.denied('grant consumption immutable','update public.boss_bucks_consumptions set amount_minor=1','23514');
select pg_temp.denied('tender correlation immutable','update public.boss_bucks_tenders set checkout_id=gen_random_uuid()','23514');
select pg_temp.denied('ledger source restriction immutable','update public.boss_bucks_grants set organization_id=pg_temp.f(''other-org'')','23514');
select pg_temp.denied('ledger source currency immutable','update public.boss_bucks_grants set currency=''CAD''','23514');
do $$declare t record;r text;begin
 perform pg_temp.check('six payment lineage and recovery tables exist','ACL',(select count(*)=6 from pg_class where relnamespace='public'::regnamespace and relkind='r'and relname in(
 'boss_bucks_tenders','boss_bucks_consumptions','boss_bucks_restorations','boss_bucks_source_corrections','boss_bucks_recovery_claims','boss_bucks_recovery_movements')));
 for t in select oid,relname,relrowsecurity from pg_class where relnamespace='public'::regnamespace and relkind='r'and relname in(
 'boss_bucks_tenders','boss_bucks_consumptions','boss_bucks_restorations','boss_bucks_source_corrections','boss_bucks_recovery_claims','boss_bucks_recovery_movements')loop
 perform pg_temp.check(t.relname||' RLS','ACL',t.relrowsecurity);
 foreach r in array array['anon','authenticated','service_role']loop perform pg_temp.check(t.relname||' closed '||r,'ACL',not has_table_privilege(r,t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;
 end loop;
 for t in select oid,proname,prosecdef,proconfig from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'and proname not in('bucks_read','bucks_mutate','bucks_admin_feature')loop
 foreach r in array array['anon','authenticated','service_role']loop perform pg_temp.check(t.proname||' closed '||r,'TRUSTED',not has_function_privilege(r,t.oid,'execute'));end loop;
 perform pg_temp.check(t.proname||' empty search path','PATH',t.proconfig@>array['search_path=""']);end loop;
end$$;
select pg_temp.check('public money RPC remains invoker','BOUNDARY',not(select prosecdef from pg_proc where oid='public.boss_bucks_mutate(jsonb)'::regprocedure));
select pg_temp.check('no broad family spend role was introduced','AUTH',not exists(select 1 from public.permissions where key='boss_bucks.spend'));
select pg_temp.check('only finite finance and administrator roles receive reversal potential','AUTH',
 (select array_agg(r.key order by r.key)from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where p.key='boss_bucks.payment_reverse')=
 array['finance','organization_administrator','organization_finance','organization_owner','platform_administrator','super_administrator']);
select count(*)passed_assertions,'Phase 7C integrity' suite from phase5a_assertions;rollback;
