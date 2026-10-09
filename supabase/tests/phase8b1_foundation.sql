\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8b1/fixture.sql
select pg_temp.check('no operational provider','ACTIVATION',not exists(select 1 from public.partner_config_revisions where operational or credentials_ready));
select pg_temp.check('native offer independent','NATIVE',boss_private.merchant_available(pg_temp.mid('offer'),pg_temp.mid('loc-a')));
select pg_temp.check('valid current source reused','ENTITLEMENT',(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'membership_eligible')::boolean);
select pg_temp.check('exact territory passes','TERRITORY',(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'territory_eligible')::boolean);
select pg_temp.check('reviewed catalog current','CATALOG',(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'catalog_available')::boolean);
select pg_temp.check('licensing reviewed independently','LICENSING',(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'licensing_valid')::boolean);
select pg_temp.check('eligible is not operational or visible','ACTIVATION',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'visible')::boolean);
select pg_temp.check('wrong country denied','TERRITORY',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market-ca','market_id'))->>'territory_eligible')::boolean);
select pg_temp.check('wrong market denied','TERRITORY',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market-other','market_id'))->>'territory_eligible')::boolean);
select pg_temp.check('nonmember denied','ENTITLEMENT',not(boss_private.partner_decision(pg_temp.f('staff'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'membership_eligible')::boolean);
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('member sees honest empty discovery','PUBLIC',public.boss_partners_read('{"mode":"discovery"}')->'benefits'='[]'::jsonb);
select pg_temp.denied('merchant owner not provider admin','select public.boss_partners_read()');
select pg_temp.actor('admin');
select pg_temp.denied('activation explicitly locked',format('select pg_temp.pm(''activate'',''integration.activate'',%L)',pg_temp.pi()));
select pg_temp.denied('configuration cannot embed secrets',format('select pg_temp.pm(''secret'',''configuration.create'',%L)',pg_temp.pi('{"password":"inert-forbidden-field"}')),'PT422');
select pg_temp.denied('forged sibling contract',format('select pg_temp.pm(''forged'',''contract.review'',%L)',jsonb_build_object('provider_id',pg_temp.pid('provider-b'),'contract_id',pg_temp.pid('contract'),'state','approved','approval_reference','Synthetic forbidden scope')),'PT404');
select pg_temp.denied('author cannot self approve',format('select pg_temp.pm(''self-approve'',''contract.review'',%L)',pg_temp.pi(jsonb_build_object('contract_id',pg_temp.pid('contract'),'state','approved','approval_reference','Synthetic self approval'))),'PT409');
select pg_temp.check('safe bounded admin projection','PUBLIC',jsonb_array_length(public.boss_partners_read('{"limit":1}')->'providers')=1);
reset role;
do $$declare t record;role text;f record;begin
 for t in select schemaname,tablename from pg_tables where schemaname in('public','boss_private')and tablename like'partner_%'loop
 perform pg_temp.check(t.tablename||' RLS','RLS',(select relrowsecurity from pg_class where oid=(t.schemaname||'.'||t.tablename)::regclass));
 foreach role in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check(t.tablename||' raw denied '||role,'ACL',not has_table_privilege(role,t.schemaname||'.'||t.tablename,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;end loop;
 for f in select oid,proname,proconfig from pg_proc where pronamespace='boss_private'::regnamespace and proname like'partner_%'loop
 perform pg_temp.check(f.proname||' path pinned','ACL',coalesce(f.proconfig,'{}')@>array['search_path=""']);
 if f.proname not in('partner_mutate','partner_read')then foreach role in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check(f.proname||' helper denied '||role,'ACL',not has_function_privilege(role,f.oid,'EXECUTE'));end loop;end if;end loop;
end$$;
select pg_temp.denied('immutable contract','update public.partner_contract_revisions set display_rights=false','23514');
select pg_temp.denied('immutable benefit terms','update public.partner_benefit_revisions set member_terms=''forged''','23514');
select pg_temp.denied('operational raw lock','insert into public.partner_config_revisions select gen_random_uuid(),provider_id,999,module_id,method,capabilities,credential_reference,false,true,full_withdraw_missing,max_stale_seconds,starts_at,ends_at,created_by,created_at from public.partner_config_revisions limit 1','23514');
set local role anon;select pg_temp.check('public empty and private free','PUBLIC',public.boss_partners_directory()->'benefits'='[]'::jsonb);select pg_temp.denied('anonymous signed read','select public.boss_partners_read()','42501');reset role;
set constraints all immediate;
select count(*)passed_assertions,'Phase 8B1 provider/licensing/security foundation'::text suite from phase5a_assertions;rollback;
