\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8a/fixture.sql
do $$declare t text;role text;begin for t in select tablename from pg_tables where schemaname='public'and(tablename like'merchant_%'or tablename='merchants')loop
 perform pg_temp.check(t||' RLS','RLS',(select relrowsecurity from pg_class where oid=('public.'||t)::regclass));
 foreach role in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check(t||' raw denies '||role,'ACL',not has_table_privilege(role,'public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;end loop;
 for t in select tablename from pg_tables where schemaname='boss_private'and tablename like'merchant_%'loop
 foreach role in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check('private '||t||' raw denies '||role,'ACL',not has_table_privilege(role,'boss_private.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;end loop;
end$$;
select pg_temp.check('helpers pin search path','ACL',not exists(select 1 from pg_proc where pronamespace='boss_private'::regnamespace and proname like'merchant_%'and not coalesce(proconfig,'{}')@>array['search_path=""']));
select pg_temp.check('only signed entrypoints open','ACL',not exists(select 1 from pg_proc where pronamespace='boss_private'::regnamespace and proname like'merchant_%'and proname not in('merchant_read','merchant_mutate')and(has_function_privilege('anon',oid,'EXECUTE')or has_function_privilege('authenticated',oid,'EXECUTE')or has_function_privilege('service_role',oid,'EXECUTE')or has_function_privilege('boss_payment_worker',oid,'EXECUTE'))));
select pg_temp.check('merchant owner is canonical person','IDENTITY',(select person_id=pg_temp.f('parent')from public.merchant_access_assignments a join public.roles r on r.id=a.role_id where a.merchant_id=pg_temp.mid('merchant','merchant_id')and r.key='merchant_owner'));
select pg_temp.check('no fake organizations created','TENANCY',(select count(*)=2 from public.organizations));
select pg_temp.check('unapproved merchant stays prospect','REVIEW',(select status='prospect'and claim_state='unclaimed'from public.merchants where id=pg_temp.mid('merchant-other','merchant_id')));
set local role authenticated;select pg_temp.actor('staff');
select pg_temp.denied('clerk cannot read company portal without location',format('select public.boss_merchants_read(%L)',pg_temp.mi('{"mode":"portal"}')));
select pg_temp.check('clerk sees exact active offer','SCOPE',jsonb_array_length(public.boss_merchants_read(pg_temp.mi(jsonb_build_object('mode','portal','location_id',pg_temp.mid('loc-a'))))->'offers')=1);
select pg_temp.denied('clerk sibling location denial',format('select public.boss_merchants_read(%L)',pg_temp.mi(jsonb_build_object('mode','portal','location_id',pg_temp.mid('loc-b')))));
select pg_temp.denied('clerk cannot edit profile',format('select pg_temp.mm(''clerk-profile'',''merchant.edit'',%L)',pg_temp.mi('{"expected_version":3,"name":"FORGED"}')));
select pg_temp.denied('clerk cannot create offer family',format('select pg_temp.mm(''clerk-family'',''family.create'',%L)',pg_temp.mi('{"reset_period":"lifetime","usage_timezone":"UTC"}')));
select pg_temp.denied('clerk cannot assign user',format('select pg_temp.mm(''clerk-grant'',''access.grant'',%L)',pg_temp.mi(jsonb_build_object('person_id',pg_temp.f('staff'),'role','merchant_admin'))));
select pg_temp.actor('coach');
select pg_temp.denied('manager cannot edit sibling',format('select pg_temp.mm(''manager-sibling'',''location.edit'',%L)',pg_temp.mi(jsonb_build_object('location_id',pg_temp.mid('loc-b'),'expected_version',1,'status','paused'))));
select pg_temp.mm('manager-pause','offer.local',pg_temp.mi(jsonb_build_object('family_id',pg_temp.mid('family'),'location_id',pg_temp.mid('loc-a'),'paused',true)));
select pg_temp.actor('admin');select pg_temp.mm('manager-end','access.end',pg_temp.mi(jsonb_build_object('assignment_id',pg_temp.mid('manager'))));
select pg_temp.actor('coach');select pg_temp.denied('stale local pause receipt denial after revocation',format('select pg_temp.mm(''manager-pause'',''offer.local'',%L)',pg_temp.mi(jsonb_build_object('family_id',pg_temp.mid('family'),'location_id',pg_temp.mid('loc-a'),'paused',true))));
select pg_temp.actor('parent');
select pg_temp.denied('owner cannot approve listing',format('select pg_temp.mm(''owner-review'',''merchant.review'',%L)',pg_temp.mi('{"state":"active","reason":"Attempted self reviewed approval"}')));
select pg_temp.denied('owner cannot grant owner',format('select pg_temp.mm(''owner-transfer'',''access.grant'',%L)',pg_temp.mi(jsonb_build_object('person_id',pg_temp.f('coach'),'role','merchant_owner'))),'PT422');
select pg_temp.denied('forged team identifiers rejected',format('select pg_temp.mm(''forged-team'',''merchant.edit'',%L)',pg_temp.mi(jsonb_build_object('expected_version',3,'team_id',pg_temp.f('falcons')))),'PT422');
select pg_temp.denied('unrelated merchant denied',format('select public.boss_merchants_read(%L)',jsonb_build_object('mode','portal','merchant_id',pg_temp.mid('merchant-other','merchant_id'))));
reset role;
select pg_temp.denied('immutable offer rewrite rejected','update public.merchant_offer_revisions set discount_bps=9000','23514');
select pg_temp.denied('immutable role resource cannot move','update public.merchant_access_assignments set merchant_id='''||pg_temp.mid('merchant-other','merchant_id')||'''','23514');
set constraints all immediate;
select count(*)passed_assertions,'Phase 8A merchant identity and authorization'::text suite from phase5a_assertions;rollback;
