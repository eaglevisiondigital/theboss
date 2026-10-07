\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/fixture.sql
select pg_temp.success('rails-source',10000);
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
select pg_temp.f('org'),id,'active','{"online_payments":true,"provider_configuration":true,"settlement":true}',now()-interval'1 day' from public.modules where key='payments';
insert into public.processing_accounts(id,organization_id,provider,environment,name,country,currencies,merchant_owner,merchant_reference,settlement_mode,capabilities,status,created_by)
values(pg_temp.f('rails-account'),pg_temp.f('org'),'authorize_net','sandbox','LOCAL CONTROLLED CONTRACT','US',array['USD'],'organization','LOCAL-CONTRACT-MERCHANT','direct_provider',array['card_sale','auth_capture'],'active',pg_temp.f('admin'));
insert into boss_private.processing_bindings(account_id,secret_handle,credential_revision,verified_environment,verified_merchant_reference,verified_at)
values(pg_temp.f('rails-account'),'boss/payments/local-contract-only',pg_temp.f('rails-revision'),'sandbox','LOCAL-CONTRACT-MERCHANT',clock_timestamp());
insert into public.payment_routing_revisions(id,organization_id,account_id,purpose,currency,scope_type,scope_id,revision,starts_at,created_by)
values(pg_temp.f('rails-route'),pg_temp.f('org'),pg_temp.f('rails-account'),'fees','USD','organization',pg_temp.f('org'),1,now()-interval'1 day',pg_temp.f('admin'));
insert into public.payment_routing_events(routing_id,state,actor_id)values(pg_temp.f('rails-route'),'active',pg_temp.f('admin'));

select pg_temp.check('processing readiness requires exact verified account','ROUTING',boss_private.rails_account_ready(pg_temp.f('rails-account'),pg_temp.f('org'),'card','USD'));
select pg_temp.check('wrong organization cannot route','ISOLATION',not boss_private.rails_account_ready(pg_temp.f('rails-account'),pg_temp.f('other-org'),'card','USD'));
select pg_temp.check('unsupported account ACH cannot route','CAPABILITY',not boss_private.rails_account_ready(pg_temp.f('rails-account'),pg_temp.f('org'),'ach','USD'));
select pg_temp.check('wrong currency cannot route','CURRENCY',not boss_private.rails_account_ready(pg_temp.f('rails-account'),pg_temp.f('org'),'card','CAD'));
select pg_temp.check('same organization charge route','ROUTING',boss_private.rails_route_charge(pg_temp.f('rails-route'),pg_temp.f('charge-camp')));
select pg_temp.check('cross-organization charge denied','ROUTING',not boss_private.rails_route_charge(pg_temp.f('rails-route'),pg_temp.f('charge-other')));
select pg_temp.check('confirmed identity is active','IDENTITY',boss_private.rails_actor_current(pg_temp.f('parent')));
select pg_temp.check('explicit payment guardian authorizes charge','GUARDIAN',boss_private.rails_charge_authorized(pg_temp.f('parent'),pg_temp.f('charge-camp')));
select pg_temp.check('household alone cannot pay','GUARDIAN',not boss_private.rails_charge_authorized(pg_temp.f('household-only'),pg_temp.f('charge-camp')));
select pg_temp.check('unrelated child cannot pay','GUARDIAN',not boss_private.rails_charge_authorized(pg_temp.f('parent'),pg_temp.f('charge-unrelated-child')));
select pg_temp.check('platform admin can manage provider','ROLE',boss_private.rails_role(pg_temp.f('admin'),'payments.provider_manage',pg_temp.f('org')));
select pg_temp.check('coach cannot manage provider','ROLE',not boss_private.rails_role(pg_temp.f('coach'),'payments.provider_manage',pg_temp.f('org')));
select pg_temp.check('new worker cannot login/bypass RLS','WORKER',exists(select 1 from pg_roles where rolname='boss_payment_worker'and not rolcanlogin and not rolsuper and not rolbypassrls));
select pg_temp.check('no production processing accounts seeded','CONFIG',not exists(select 1 from public.processing_accounts where environment='production'));
select pg_temp.check('no invented settlement policy seeded','CONFIG',not exists(select 1 from public.settlement_policy_revisions));
select pg_temp.check('no operational recurring work seeded','CONFIG',not exists(select 1 from public.payment_recurring_work));
do $$declare permission text;expected text[];begin
foreach permission in array array['payments.provider_manage','payments.refund','settlements.view','settlements.manage','settlements.reconcile']loop
expected:=case permission when 'payments.provider_manage'then array['organization_administrator','organization_owner','platform_administrator','super_administrator']
else array['finance','organization_administrator','organization_finance','organization_owner','platform_administrator','super_administrator']end;
perform pg_temp.check(permission||' exact approved potential roles','ROLE',
(select array_agg(r.key order by r.key)from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where p.key=permission)=expected);
end loop;end$$;
set constraints rails_external_payment_proof immediate;
select pg_temp.denied('owner cannot fabricate card payment without provider proof',format('insert into public.payments(organization_id,method,amount_minor,currency,payer_person_id,received_at,recorded_by_person_id)values(%L,''card'',100,''USD'',%L,clock_timestamp(),%L)',pg_temp.f('org'),pg_temp.f('parent'),pg_temp.f('parent')),'23514');
select pg_temp.denied('owner cannot fabricate settled ACH payment without proof',format('insert into public.payments(organization_id,method,amount_minor,currency,payer_person_id,received_at,recorded_by_person_id)values(%L,''ach'',100,''USD'',%L,clock_timestamp(),%L)',pg_temp.f('org'),pg_temp.f('parent'),pg_temp.f('parent')),'23514');
set constraints rails_external_payment_proof deferred;

do $$declare t text;r text;begin
foreach t in array array['processing_accounts','payment_routing_revisions','payment_routing_events','settlement_policy_revisions','payment_checkouts','checkout_charge_allocations','boss_bucks_checkout_reservations','payment_checkout_events','provider_operations','provider_event_evidence','external_payment_tenders','saved_payment_methods','payment_execution_consents','payment_recurring_work','payment_history','payment_eligibility_commits','payment_attempt_invalidations','payment_review_cases','settlement_sources','settlement_events','settlement_accounts','settlement_journals','settlement_postings','settlement_requests','settlement_request_items','settlement_request_history','payment_refund_requests','external_payment_corrections','payment_dispute_cases','settlement_deficits','settlement_deficit_offsets','payment_reconciliation_runs','payment_reconciliation_items']loop
perform pg_temp.check(t||' RLS','RLS',(select relrowsecurity from pg_class where oid=('public.'||t)::regclass));
foreach r in array array['anon','authenticated','service_role','boss_payment_worker']loop
perform pg_temp.check(t||' closed to '||r,'ACL',not has_table_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;end loop;
end$$;
select pg_temp.check('all new private routines close direct execution','ACL',not exists(select 1 from pg_proc where pronamespace='boss_private'::regnamespace and proname like'rails_%'and proname not in('rails_read','rails_mutate','rails_worker_claim','rails_worker_finish','rails_reconcile_batch','rails_review_due','rails_profile_register')and(has_function_privilege('anon',oid,'EXECUTE')or has_function_privilege('authenticated',oid,'EXECUTE')or has_function_privilege('service_role',oid,'EXECUTE')or has_function_privilege('boss_payment_worker',oid,'EXECUTE'))));
select pg_temp.check('only finite anonymous fundraising and checkout boundaries','ACL',(select count(*)=3 and bool_and(proname in('read','support','payments'))from pg_proc where pronamespace='boss_fundraising_public'::regnamespace));
select pg_temp.check('all private routine search paths pinned','SEARCH_PATH',not exists(select 1 from pg_proc where pronamespace='boss_private'::regnamespace and proname like'rails_%'and not coalesce(proconfig,'{}')@>array['search_path=""']));

insert into public.payment_checkouts(id,organization_id,actor_person_id,purpose,currency,account_id,routing_id,method,wallet_id,principal_minor,bucks_minor,external_minor,request_id,command_hash,expires_at)
values(pg_temp.f('rails-checkout'),pg_temp.f('org'),pg_temp.f('parent'),'fees','USD',pg_temp.f('rails-account'),pg_temp.f('rails-route'),'card',pg_temp.w(),10000,3000,7000,pg_temp.f('rails-request'),repeat('a',64),clock_timestamp()+interval'15 minutes');
insert into public.checkout_charge_allocations(checkout_id,organization_id,charge_id,principal_minor,bucks_minor)
values(pg_temp.f('rails-checkout'),pg_temp.f('org'),pg_temp.f('charge-camp'),10000,3000);
insert into public.boss_bucks_checkout_reservations(checkout_id,grant_id,amount_minor)
select pg_temp.f('rails-checkout'),id,3000 from public.boss_bucks_grants;
select pg_temp.check('reservation lowers competing availability','RESERVATION',boss_private.bucks_available(pg_temp.w())=2000);
select pg_temp.check('reservation does not debit wallet journals','LEDGER',(select count(*)=0 from public.boss_bucks_journals where kind='spend'));
select pg_temp.check('reservation does not become canonical payment','PAYMENT',not exists(select 1 from public.payments));
select pg_temp.check('charge reserve protects principal','RESERVATION',boss_private.rails_charge_reserved(pg_temp.f('charge-camp'))=10000);
select pg_temp.check('own reservation excluded during commit recheck','RESERVATION',boss_private.rails_charge_reserved(pg_temp.f('charge-camp'),pg_temp.f('rails-checkout'))=0);
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.conflict('competing Bucks cannot consume reserved slices',format('select pg_temp.bm(''payment.spend'',%L)',pg_temp.spend_input(2001,'church')));
select pg_temp.bm('payment.spend',pg_temp.spend_input(1000,'church'));
reset role;
select pg_temp.check('existing spend uses only free grant balance','LEDGER',boss_private.bucks_available(pg_temp.w())=1000 and(select sum(amount_minor)=1000 from public.boss_bucks_consumptions));
select pg_temp.denied('checkout expiry cannot be extended',format('update public.payment_checkouts set expires_at=expires_at+interval''1 minute''where id=%L',pg_temp.f('rails-checkout')),'23514');
select pg_temp.denied('checkout amount cannot rewrite',format('update public.payment_checkouts set principal_minor=principal_minor+1,external_minor=external_minor+1 where id=%L',pg_temp.f('rails-checkout')),'23514');
select pg_temp.denied('merchant identity cannot rewrite',format('update public.processing_accounts set merchant_reference=''OTHER''where id=%L',pg_temp.f('rails-account')),'23514');
update public.payment_checkouts set state='failed'where id=pg_temp.f('rails-checkout');
select pg_temp.check('failed checkout releases wallet reserve','RESERVATION',boss_private.bucks_available(pg_temp.w())=4000);
select pg_temp.check('failed checkout releases charge reserve','RESERVATION',boss_private.rails_charge_reserved(pg_temp.f('charge-camp'))=0);

insert into public.payment_checkouts(id,organization_id,actor_person_id,purpose,currency,account_id,routing_id,method,principal_minor,external_minor,request_id,command_hash,state,created_at,expires_at)
select pg_temp.f('rails-'||s),pg_temp.f('org'),pg_temp.f('parent'),'fees','USD',pg_temp.f('rails-account'),pg_temp.f('rails-route'),'card',10000,10000,pg_temp.f('rails-request-'||s),repeat('b',64),case when s='unknown' then 'unknown'else 'ready'end,clock_timestamp()-interval'20 minutes',clock_timestamp()-interval'5 minutes'
from unnest(array['expired','unknown'])s;
insert into public.checkout_charge_allocations(checkout_id,organization_id,charge_id,principal_minor,bucks_minor)
select pg_temp.f('rails-'||s),pg_temp.f('org'),pg_temp.f('charge-camp'),10000,0 from unnest(array['expired','unknown'])s;
insert into public.provider_operations(organization_id,checkout_id,account_id,kind,request_id,provider_request_reference,amount_minor,currency,state,dispatched_at)
values(pg_temp.f('org'),pg_temp.f('rails-unknown'),pg_temp.f('rails-account'),'sale',pg_temp.f('rails-operation-request'),'localcontract0000001',10000,'USD','unknown',clock_timestamp()-interval'19 minutes');
select pg_temp.check('submitted unknown retains charge hold beyond short expiry','EXPIRY',boss_private.rails_charge_reserved(pg_temp.f('charge-camp'))=10000);
select pg_temp.check('unknown outcome still blocks a new external attempt','UNKNOWN',boss_private.rails_charge_unknown(pg_temp.f('charge-camp')));
insert into payment_results values('expiry',jsonb_build_object('count',boss_private.rails_expire()));
select pg_temp.check('expiry handles undispatched checkout only','EXPIRY',(select result->>'count'='1'from payment_results where label='expiry')and(select state='expired'from public.payment_checkouts where id=pg_temp.f('rails-expired')));
select pg_temp.check('expiry does not manufacture failed unknown outcome','UNKNOWN',(select state='unknown'from public.payment_checkouts where id=pg_temp.f('rails-unknown')));
select pg_temp.check('expiry replay has no duplicate effect','IDEMPOTENCY',boss_private.rails_expire()=0 and(select count(*)=1 from public.payment_checkout_events where kind='expired'));
select pg_temp.denied('unbounded expiry batch denied','select boss_private.rails_expire(101)','PT422');
update public.user_accounts set account_status='suspended' where person_id=pg_temp.f('parent');
select pg_temp.check('inactive payer identity loses authority','IDENTITY',not boss_private.rails_actor_current(pg_temp.f('parent')) and not boss_private.rails_charge_authorized(pg_temp.f('parent'),pg_temp.f('charge-camp')));
set constraints all immediate;
select count(*)passed_assertions,'Phase 7D local foundation only' suite from phase5a_assertions;rollback;
