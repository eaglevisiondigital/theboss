\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir global/fixture.sql
\ir global/intermediate.sql
select pg_temp.policy('money_board',pg_temp.f('falcons'));
do $$declare t record;r text;begin for t in select relname from pg_class where relnamespace='public'::regnamespace and relkind='r'and relname in('fundraising_brands','fundraising_campaign_origins','fundraising_destinations','fundraising_platform_policies','fundraising_allocation_delegations','fundraising_allocation_policies','fundraising_wallet_channel_policies','fundraising_checkout_snapshots','fundraising_credit_sources','fundraising_credit_entries','fundraising_cash_rounding_sources','fundraising_cash_rounding_corrections')loop
 foreach r in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check(t.relname||' raw '||r||' closed','ACL',not has_table_privilege(r,'public.'||t.relname,'SELECT,INSERT,UPDATE,DELETE'));end loop;
end loop;end$$;
select pg_temp.check('raw request receipts are closed and RLS protected','ACL',not has_table_privilege('authenticated','boss_private.fundraising_allocation_requests','SELECT,INSERT,UPDATE,DELETE')and(select relrowsecurity from pg_class where oid='boss_private.fundraising_allocation_requests'::regclass));
select pg_temp.check('only authenticated finite mutation gateway executes','ACL',has_function_privilege('authenticated','public.boss_fundraising_allocation_mutate(jsonb)','EXECUTE')and not has_function_privilege('anon','public.boss_fundraising_allocation_mutate(jsonb)','EXECUTE')and not has_function_privilege('service_role','public.boss_fundraising_allocation_mutate(jsonb)','EXECUTE'));
select pg_temp.check('legacy organization account/route management retained','ACL',has_function_privilege('authenticated','public.boss_payments_mutate(jsonb)','EXECUTE'));
select pg_temp.check('pre-guard payment mutator cannot be bypassed','ACL',not has_function_privilege('authenticated','boss_private.rails_mutate_before_global(jsonb)','EXECUTE'));
select pg_temp.check('organization is never platform economic actor','AUTHORITY',not boss_private.fundraising_platform_actor(pg_temp.f('admin'))and boss_private.fundraising_platform_actor(pg_temp.f('director')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('org payment UI retains account control but not policy control','AUTHORITY',public.boss_payments_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'can_configure'='true'and public.boss_payments_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'can_configure_policy'='false');
select pg_temp.actor('director');
select pg_temp.check('platform policy control remains available','AUTHORITY',public.boss_payments_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'can_configure_policy'='true');
select pg_temp.conflict('cross-currency platform revision fails closed',format('select pg_temp.am(''platform_policy.create'',%L)',jsonb_build_object('organization_id',pg_temp.f('org'),'campaign_id',pg_temp.fid('campaign'),'channel','money_board','currency','CAD','settlement_policy_id',pg_temp.f('settlement-policy'),'agreement_reference','LOCAL','participant_credit_max_bps',10000,'wallet_permitted',false,'starts_at',clock_timestamp())));
select pg_temp.conflict('wrong merchant tenant economics fail closed',format('select pg_temp.am(''platform_policy.create'',%L)',jsonb_build_object('organization_id',pg_temp.f('other-org'),'channel','direct_support','currency','USD','settlement_policy_id',pg_temp.f('settlement-policy'),'agreement_reference','LOCAL','participant_credit_max_bps',10000,'wallet_permitted',false,'starts_at',clock_timestamp())));
reset role;
create function pg_temp.integrity_denied(label text,statement text)returns void language plpgsql as $$declare blocked boolean:=false;begin
 begin execute statement;set constraints all immediate;exception when check_violation or foreign_key_violation or sqlstate'PT422'then blocked:=true;end;
 perform pg_temp.check(label,'INTEGRITY',blocked);
end$$;
select pg_temp.integrity_denied('cross-currency forged immutable envelope rejected',format('insert into public.fundraising_platform_policies(organization_id,campaign_id,channel,currency,revision,settlement_policy_id,agreement_reference,participant_credit_max_bps,wallet_permitted,starts_at,created_by)values(%L,%L,''money_board'',''CAD'',99,%L,''LOCAL'',10000,false,clock_timestamp(),%L)',pg_temp.f('org'),pg_temp.fid('campaign'),pg_temp.f('settlement-policy'),pg_temp.f('director')));
select pg_temp.integrity_denied('org policy cannot escape captured platform envelope',format('insert into public.fundraising_allocation_policies(organization_id,campaign_id,platform_policy_id,channel,revision,organization_bps,destination_bps,participant_bps,starts_at,created_by)select organization_id,campaign_id,id,''direct_support'',99,10000,0,0,clock_timestamp(),%L from public.fundraising_platform_policies limit 1',pg_temp.f('admin')));
select pg_temp.checkout('canonical-direct');
-- A contradictory provenance clone is rejected before another checkout exists.
do $$declare row_data jsonb;blocked boolean:=false;begin
 select to_jsonb(i)||jsonb_build_object('id',gen_random_uuid(),'request_id',gen_random_uuid(),'capability_digest',repeat('e',64),'provenance',i.provenance||jsonb_build_object('channel','money_board_group','organization_id',pg_temp.f('other-org')))into row_data from public.fundraising_intents i where request_id=pg_temp.f('intent-canonical-direct');
 begin insert into public.fundraising_intents select(jsonb_populate_record(null::public.fundraising_intents,row_data)).*;
  insert into public.payment_checkouts select(jsonb_populate_record(null::public.payment_checkouts,(select to_jsonb(pc)||jsonb_build_object('id',gen_random_uuid(),'request_id',gen_random_uuid(),'intent_id',row_data->>'id','capability_digest',repeat('e',64))from public.payment_checkouts pc where id=pg_temp.f('checkout-canonical-direct')))).*;
  set constraints all immediate;
 exception when check_violation or foreign_key_violation or unique_violation or sqlstate'PT422'then blocked:=true;end;
 perform pg_temp.check('forged source label and tenant cannot normalize','FORGERY',blocked);
end$$;
select pg_temp.denied('captured policy cannot be rewritten','update public.fundraising_platform_policies set participant_credit_max_bps=0','23514');
select pg_temp.denied('captured checkout cannot be rewritten','update public.fundraising_checkout_snapshots set account_id=gen_random_uuid()','23514');
set constraints all immediate;
select count(*)passed_assertions,'Global financial ACL/source integrity' suite from phase5a_assertions;rollback;
