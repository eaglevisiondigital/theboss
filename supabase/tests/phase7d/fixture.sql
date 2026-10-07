\ir ../phase7c/fixture.sql
select pg_temp.success('rails-source',10000);
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
select pg_temp.f('org'),id,'active','{"online_payments":true,"provider_configuration":true,"settlement":true}',now()-interval'1 day' from public.modules where key='payments';
insert into public.processing_accounts(id,organization_id,provider,environment,name,country,currencies,merchant_owner,merchant_reference,settlement_mode,capabilities,status,created_by)
values(pg_temp.f('rails-account'),pg_temp.f('org'),'authorize_net','sandbox','LOCAL CONTROLLED CONTRACT','US',array['USD'],'organization','LOCAL-CONTRACT-MERCHANT','direct_provider',array['card_sale','auth_capture','ach','refund','partial_refund','settlement_query'],'active',pg_temp.f('admin'));
insert into boss_private.processing_bindings(account_id,secret_handle,credential_revision,verified_environment,verified_merchant_reference,verified_at)
values(pg_temp.f('rails-account'),'boss/payments/local-contract-only',pg_temp.f('rails-revision'),'sandbox','LOCAL-CONTRACT-MERCHANT',clock_timestamp());
insert into public.payment_routing_revisions(id,organization_id,account_id,purpose,currency,scope_type,scope_id,revision,starts_at,created_by)
values(pg_temp.f('rails-route'),pg_temp.f('org'),pg_temp.f('rails-account'),'fees','USD','organization',pg_temp.f('org'),1,now()-interval'1 day',pg_temp.f('admin'));
insert into public.payment_routing_events(routing_id,state,actor_id)values(pg_temp.f('rails-route'),'active',pg_temp.f('admin'));

insert into public.payment_routing_revisions(id,organization_id,account_id,purpose,currency,scope_type,scope_id,revision,starts_at,created_by)
values(pg_temp.f('fundraising-route'),pg_temp.f('org'),pg_temp.f('rails-account'),'fundraising','USD','campaign',pg_temp.fid('campaign'),1,now()-interval'1 day',pg_temp.f('admin'));
insert into public.payment_routing_events(routing_id,state,actor_id)values(pg_temp.f('fundraising-route'),'active',pg_temp.f('admin'));
insert into public.settlement_policy_revisions(id,organization_id,purpose,currency,revision,organization_basis_points,platform_basis_points,product_cost_basis_points,processor_fee_owner,availability_seconds,created_by)
values(pg_temp.f('settlement-policy'),pg_temp.f('org'),'fundraising','USD',1,7000,3000,0,'platform',0,pg_temp.f('admin'));
create function pg_temp.checkout(label text,method text default 'card',ordinal integer default null,short boolean default false)returns uuid language plpgsql as $$
declare x public.fundraising_intents;cap text:=md5('rails'||label)||md5('rails-second'||label);i jsonb;expiry timestamptz;begin
 i:=jsonb_build_object('path',pg_temp.fpath('share'),'capability',cap,'display_name','Synthetic supporter','anonymous',true,'amount_minor',10000);
 if ordinal is not null then
 perform public.boss_fundraising_support(jsonb_build_object('action','reserve','request_id',pg_temp.f('reserve-'||label),'input',jsonb_build_object('path',pg_temp.fpath('share'),'capability',cap,'ordinal',ordinal)));
 i:=(i-'amount_minor')||jsonb_build_object('ordinal',ordinal);end if;
 perform public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',pg_temp.f('intent-'||label),'input',i));
 select *into x from public.fundraising_intents where request_id=pg_temp.f('intent-'||label);
 expiry:=case when short then clock_timestamp()+interval'60 milliseconds'else least(x.expires_at,clock_timestamp()+interval'10 minutes')end;
 insert into public.payment_checkouts(id,organization_id,intent_id,purpose,currency,account_id,routing_id,policy_id,method,principal_minor,external_minor,request_id,command_hash,capability_digest,expires_at)
 values(pg_temp.f('checkout-'||label),pg_temp.f('org'),x.id,'fundraising','USD',pg_temp.f('rails-account'),pg_temp.f('fundraising-route'),pg_temp.f('settlement-policy'),method,x.amount_minor,x.amount_minor,pg_temp.f('checkout-request-'||label),repeat('c',64),x.capability_digest,expiry);
 return pg_temp.f('checkout-'||label);
end$$;
create function pg_temp.receive(label text,kind text,event_label text default null)returns jsonb language plpgsql as $$
declare c public.payment_checkouts;e public.provider_event_evidence;ref text:=coalesce(event_label,label||'-'||kind);ts timestamptz;begin
 select *into c from public.payment_checkouts where id=pg_temp.f('checkout-'||label);
 select *into e from public.provider_event_evidence where account_id=c.account_id and event_reference=ref;
 ts:=coalesce(e.occurred_at,clock_timestamp());
 return boss_private.rails_receive(c.id,ref,kind,'LOCAL-TRANSACTION-'||label,c.external_minor,c.currency,ts,encode(sha256(convert_to(ref,'UTF8')),'hex'),
 case when kind='failed'then'{"failure_contract":"definitive_failure"}'::jsonb else'{}'::jsonb end);
end$$;
