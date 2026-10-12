\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
select pg_temp.check('prices from immutable configured revisions','PRODUCT',(select price_minor=2500 from public.discount_product_revisions where id=pg_temp.did('base30','revision_id')));
select pg_temp.check('state price 1999','PRODUCT',(select price_minor=1999 from public.discount_product_revisions where id=pg_temp.did('upgrade-state','revision_id')));
select pg_temp.check('nationwide price 3900','PRODUCT',(select price_minor=3900 from public.discount_product_revisions where id=pg_temp.did('upgrade-national','revision_id')));
do $$declare t text;role text;begin for t in select tablename from pg_tables where schemaname='public'and tablename like'discount_%'loop
 perform pg_temp.check(t||' RLS','RLS',(select relrowsecurity from pg_class where oid=('public.'||t)::regclass));
 foreach role in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check(t||' denies raw '||role,'ACL',not has_table_privilege(role,'public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;end loop;
 for t in select tablename from pg_tables where schemaname='boss_private'and tablename like'discount_%'loop
 foreach role in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check('private '||t||' denies '||role,'ACL',not has_table_privilege(role,'boss_private.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;end loop;end$$;
select pg_temp.check('only signed read/mutate private routines callable','ACL',not exists(select 1 from pg_proc where pronamespace='boss_private'::regnamespace and proname like'discount_%'and proname not in('discount_read','discount_mutate')and(has_function_privilege('anon',oid,'EXECUTE')or has_function_privilege('authenticated',oid,'EXECUTE')or has_function_privilege('service_role',oid,'EXECUTE')or has_function_privilege('boss_payment_worker',oid,'EXECUTE'))));
select pg_temp.check('all product helpers pin search path','SEARCH_PATH',not exists(select 1 from pg_proc where pronamespace='boss_private'::regnamespace and proname like'discount_%'and not coalesce(proconfig,'{}')@>array['search_path=""']));
select pg_temp.check('membership does not require a wallet','SEPARATION',not exists(select 1 from information_schema.columns where table_name='discount_memberships'and column_name in('wallet_id','balance_minor')));
set local role authenticated;select pg_temp.actor('coach');
select pg_temp.denied('coach cannot create national product',format('select pg_temp.dm(''coach-create'',''product.create'',%L)', '{"code":"forged","name":"Forged","kind":"digital"}'));
select pg_temp.denied('coach cannot read another organization product report',format('select public.boss_discounts_read(%L)',jsonb_build_object('mode','organization','organization_id',pg_temp.f('other-org'))));
select pg_temp.actor('parent');
select pg_temp.dm('trial','trial.start',jsonb_build_object('revision_id',pg_temp.did('base30','revision_id'),'path',pg_temp.fpath('share')));
select pg_temp.check('signed trial active','TRIAL',(public.boss_discounts_read(jsonb_build_object('membership_id',pg_temp.did('trial')))->'memberships'->0->'effective'->>'state')='trial');
select pg_temp.conflict('duplicate active trial refused',format('select pg_temp.dm(''trial-duplicate'',''trial.start'',%L)',jsonb_build_object('revision_id',pg_temp.did('base30','revision_id'),'path',pg_temp.fpath('share'))));
select pg_temp.actor('household-only');
select pg_temp.denied('household membership alone cannot read personal discount membership',format('select public.boss_discounts_read(%L)',jsonb_build_object('membership_id',pg_temp.did('trial'))));
select pg_temp.actor('parent');
select pg_temp.denied('forged membership denied',format('select public.boss_discounts_read(%L)',jsonb_build_object('membership_id',pg_temp.f('forged-member'))));
select pg_temp.denied('forged claim digest denied',format('select pg_temp.dm(''forged-claim'',''membership.claim'',%L)',jsonb_build_object('claim_secret',repeat('a',64))),'PT404');
reset role;
select pg_temp.check('trial entitlement reuses canonical table','ENTITLEMENT',exists(select 1 from public.discount_entitlement_links l join public.entitlements e on e.id=l.entitlement_id where e.person_id=pg_temp.f('parent')and e.entitlement_type='product'and e.source_type='discount_member_source'and e.status='active'));
select pg_temp.check('no trial wallet mutation','SEPARATION',(select count(*)=1 from public.boss_bucks_grants));
select pg_temp.check('no trial payment or charge allocation','SEPARATION',not exists(select 1 from public.discount_orders));
set constraints all immediate;
select count(*)passed_assertions,'Phase 7E membership foundation'::text suite from phase5a_assertions;
rollback;
\ir ../verification/phase7e_live.sql
