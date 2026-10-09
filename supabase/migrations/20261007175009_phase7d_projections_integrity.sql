-- Signed, bounded, deny-by-default projections and commands. Raw tables stay
-- closed; provider evidence/completion has no browser RPC or simulation route.
create function boss_private.rails_prepare(actor uuid,command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb:=command->'input';request uuid:=(command->>'request_id')::uuid;c public.payment_checkouts;r public.payment_routing_revisions;
 x jsonb;charge public.charges;total bigint:=0;bucks bigint;external bigint;wallet uuid;policy uuid;g record;take bigint;remaining bigint;begin
 perform boss_private.athlete_input(i,array['organization_id','routing_id','method','currency','allocations','wallet_id','bucks_minor'],array['organization_id','routing_id','method','currency','allocations','bucks_minor']);
 if jsonb_typeof(i->'allocations')is distinct from'array'or jsonb_array_length(i->'allocations')not between 1 and 50 or i->>'method'not in('card','ach')then raise exception'Invalid checkout input'using errcode='PT422';end if;
 select *into c from public.payment_checkouts where request_id=request;
 if c.id is not null then
 perform boss_private.games_require_live_auth();if c.actor_person_id is distinct from actor or c.command_hash<>encode(sha256(convert_to(command::text,'UTF8')),'hex')then raise exception'Checkout replay conflict'using errcode='PT409';end if;
 return jsonb_build_object('checkout_id',c.id,'state',c.state,'replayed',true);end if;
 select *into r from public.payment_routing_revisions where id=(i->>'routing_id')::uuid;
 if r.id is null or r.organization_id is distinct from(i->>'organization_id')::uuid or r.purpose<>'fees'or r.currency is distinct from i->>'currency'
 or not boss_private.rails_account_ready(r.account_id,r.organization_id,i->>'method',r.currency)or not boss_private.rails_route_current(r.id)then raise exception'No configured processing route'using errcode='PT409';end if;
 bucks:=boss_private.rails_amount(i,'bucks_minor',true);wallet:=(i->>'wallet_id')::uuid;
 perform boss_private.rails_fence(actor,r.organization_id,wallet);
 for x in select value from jsonb_array_elements(i->'allocations')order by(value->>'charge_id')::uuid loop
 perform boss_private.athlete_input(x,array['charge_id','amount_minor','bucks_minor'],array['charge_id','amount_minor','bucks_minor']);
 if not boss_private.rails_charge_authorized(actor,(x->>'charge_id')::uuid)or not boss_private.rails_route_charge(r.id,(x->>'charge_id')::uuid)then raise exception'Access denied'using errcode='PT403';end if;
 select *into charge from public.charges where id=(x->>'charge_id')::uuid for update;update public.charges set status=status where id=charge.id;
 select *into c from public.payment_checkouts where request_id=request;
 if c.id is not null then perform boss_private.games_require_live_auth();if c.actor_person_id is distinct from actor or c.command_hash<>encode(sha256(convert_to(command::text,'UTF8')),'hex')then raise exception'Checkout replay conflict'using errcode='PT409';end if;return jsonb_build_object('checkout_id',c.id,'state',c.state,'replayed',true);end if;
 if boss_private.rails_charge_unknown(charge.id)or boss_private.rails_amount(x,'amount_minor')> (boss_private.registration_charge_balance(charge.id)->>'balance_due_minor')::bigint-boss_private.rails_charge_reserved(charge.id)
 or boss_private.rails_amount(x,'bucks_minor',true)>boss_private.rails_amount(x,'amount_minor')then raise exception'Obligation is reserved or changed'using errcode='PT409';end if;
 total:=total+(x->>'amount_minor')::bigint;end loop;
 if total>1000000000 or(select count(distinct(value->>'charge_id')::uuid)from jsonb_array_elements(i->'allocations'))<>jsonb_array_length(i->'allocations')
 or(select sum((value->>'bucks_minor')::bigint)from jsonb_array_elements(i->'allocations'))<>bucks then raise exception'Canonical allocation sum mismatch'using errcode='PT422';end if;
 external:=total-bucks;if external<1 then raise exception'Use canonical wallet-only checkout'using errcode='PT422';end if;
 if bucks>0 then
 perform boss_private.bucks_wallet_lock(wallet);
 if not boss_private.bucks_accessible(actor,wallet,true)or not boss_private.bucks_payment_features(r.organization_id)or not boss_private.bucks_feature(r.organization_id,'split_tender')
 or exists(select 1 from jsonb_array_elements(i->'allocations')leg where not boss_private.bucks_charge_authorized(actor,wallet,(leg->>'charge_id')::uuid))or boss_private.bucks_available(wallet,r.organization_id)<bucks then raise exception'Wallet split eligibility changed'using errcode='PT409';end if;end if;
 perform boss_private.games_require_live_auth();if actor is distinct from boss_private.current_person_id()then raise exception'Authentication required'using errcode='PT401';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-payment-request:'||request,0));
 select *into c from public.payment_checkouts where request_id=request;
 if c.id is not null then if c.actor_person_id<>actor or c.command_hash<>encode(sha256(convert_to(command::text,'UTF8')),'hex')then raise exception'Checkout replay conflict'using errcode='PT409';end if;return jsonb_build_object('checkout_id',c.id,'state',c.state,'replayed',true);end if;
 perform boss_private.rails_rate('person:'||actor,30);
 select id into policy from public.settlement_policy_revisions where organization_id=r.organization_id and purpose='fees'and currency=r.currency order by revision desc limit 1;
 insert into public.payment_checkouts(organization_id,actor_person_id,purpose,currency,account_id,routing_id,policy_id,method,wallet_id,principal_minor,bucks_minor,external_minor,request_id,command_hash,expires_at)
 values(r.organization_id,actor,'fees',r.currency,r.account_id,r.id,policy,i->>'method',case when bucks>0 then wallet end,total,bucks,external,request,encode(sha256(convert_to(command::text,'UTF8')),'hex'),clock_timestamp()+interval'10 minutes')returning *into c;
 insert into public.checkout_charge_allocations(checkout_id,organization_id,charge_id,principal_minor,bucks_minor)
 select c.id,c.organization_id,(value->>'charge_id')::uuid,(value->>'amount_minor')::bigint,(value->>'bucks_minor')::bigint from jsonb_array_elements(i->'allocations');
 remaining:=bucks;
 if remaining>0 then for g in select gr.*,boss_private.bucks_grant_book(gr.id)-boss_private.rails_grant_reserved(gr.id)free from public.boss_bucks_grants gr
 where wallet_id=wallet and organization_id=r.organization_id and currency=r.currency and available_at<=clock_timestamp()and(expires_at is null or expires_at>clock_timestamp())
 order by expires_at nulls last,available_at,created_at,id limit 200 loop
 take:=least(remaining,g.free);if take<=0 then continue;end if;
 insert into public.boss_bucks_checkout_reservations(checkout_id,grant_id,amount_minor)values(c.id,g.id,take);remaining:=remaining-take;exit when remaining=0;end loop;
 if remaining<>0 then raise exception'Bounded wallet slice changed'using errcode='PT409';end if;end if;
 insert into public.payment_checkout_events(checkout_id,kind)values(c.id,'ready');perform boss_private.rails_audit(actor,c.organization_id,'payment.checkout.prepared',c.id,request,jsonb_build_object('principal_minor',total,'bucks_minor',bucks,'external_minor',external));
 return jsonb_build_object('checkout_id',c.id,'state',c.state,'principal_minor',total,'bucks_minor',bucks,'external_minor',external,'expires_at',c.expires_at,'replayed',false);
end$$;

create function boss_private.rails_read(query jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;org uuid;mode text;result jsonb;manager boolean;finance boolean;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();if actor is null then raise exception'Authentication required'using errcode='PT401';end if;
 perform boss_private.athlete_input(query,array['mode','organization_id','before','charge_id'],array[]::text[]);
 mode:=coalesce(query->>'mode','family');org:=(query->>'organization_id')::uuid;
 if mode='organization'then
 manager:=boss_private.rails_role(actor,'payments.provider_manage',org);finance:=boss_private.rails_role(actor,'settlements.view',org);
 if not manager and not finance then raise exception'Access denied'using errcode='PT403';end if;
 result:=jsonb_build_object('mode',mode,'organization_id',org,'can_configure',manager,'can_refund',boss_private.rails_role(actor,'payments.refund',org),'can_request',boss_private.rails_role(actor,'settlements.manage',org),
 'features',jsonb_build_object('online_payments',boss_private.rails_feature(org,'online_payments'),'settlement',boss_private.rails_feature(org,'settlement')),
 'accounts',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'provider',provider,'environment',environment,'status',status,'currencies',currencies,'merchant_owner',merchant_owner,'settlement_mode',settlement_mode,'capabilities',capabilities,'statement_descriptor',statement_descriptor))from(select *from public.processing_accounts where organization_id=org order by created_at desc,id limit 50)a),'[]')else'[]'::jsonb end,
 'routing_scopes',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',rid,'kind',kind,'label',label))from(
 select org rid,'organization'::text kind,(select name from public.organizations where id=org)label union all
 select id,'team',name from(select id,name from public.teams where organization_id=org and status='active'order by id limit 50)t union all
 select id,'unit',name from(select id,name from public.organization_units where organization_id=org and status='active'order by id limit 50)u union all
 select id,'campaign',name from(select id,name from public.fundraising_campaigns where organization_id=org and status not in('canceled','archived')order by id limit 50)c)scope),'[]')else'[]'::jsonb end,
 'routes',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',id,'account_id',account_id,'purpose',purpose,'currency',currency,'scope_type',scope_type,'scope_id',scope_id,'revision',revision,'active',boss_private.rails_route_current(id)))from(select *from public.payment_routing_revisions where organization_id=org order by created_at desc,id limit 100)r),'[]')else'[]'::jsonb end,
 'settlement',case when finance then coalesce((select jsonb_agg(jsonb_build_object('payment_id',payment_id,'method',method,'currency',currency,'purpose',purpose,'mode',settlement_mode,'gross_minor',gross_minor,'principal_minor',principal_minor,'donor_fee_minor',donor_fee_minor,'platform_fee_minor',platform_fee_minor,'policy_id',policy_id,'available_at',available_at,
 'refunded_minor',(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=s.payment_id),'organization_payable_minor',boss_private.rails_source_payable(payment_id),'state',case when exists(select 1 from public.settlement_events where settlement_events.payment_id=s.payment_id and kind='settled')then'provider_settled'when policy_id is null or purpose='unallocated'then'held'else'pending'end))from(select *from public.settlement_sources where organization_id=org and(query->>'before'is null or payment_id<(query->>'before')::uuid)order by payment_id desc limit 100)s),'[]')else'[]'::jsonb end,
 'requests',case when finance then coalesce((select jsonb_agg(jsonb_build_object('id',id,'currency',currency,'amount_minor',amount_minor,'state',state,'created_at',created_at))from(select *from public.settlement_requests where organization_id=org order by created_at desc,id limit 50)r),'[]')else'[]'::jsonb end,
 'deficits',case when finance then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'currency',d.currency,'amount_minor',d.amount_minor,'remaining_minor',d.amount_minor-(select coalesce(sum(amount_minor),0)from public.settlement_deficit_offsets where deficit_id=d.id)))from(select *from public.settlement_deficits where organization_id=org order by created_at desc,id limit 50)d),'[]')else'[]'::jsonb end,
 'reconciliation',case when finance then coalesce((select jsonb_agg(jsonb_build_object('id',ri.id,'state',ri.state,'created_at',ri.created_at))from(select i.*from public.payment_reconciliation_items i join public.payment_reconciliation_runs r on r.id=i.run_id join public.processing_accounts a on a.id=r.account_id where a.organization_id=org order by i.created_at desc,i.id limit 100)ri),'[]')else'[]'::jsonb end,
 'available',case when finance then coalesce((select jsonb_agg(jsonb_build_object('currency',cur,'amount_minor',boss_private.rails_payable(org,cur)))from(select distinct currency cur from public.settlement_sources where organization_id=org)c),'[]')else'[]'::jsonb end);
 elsif mode='family'then
 result:=jsonb_build_object('mode',mode,'charges',coalesce((select jsonb_agg(jsonb_build_object('id',id,'organization_id',organization_id,'title',title,'participant_id',participant_id,'currency',currency,'balance',boss_private.registration_charge_balance(id),'reserved_minor',boss_private.rails_charge_reserved(id),'eligible_bucks_minor',coalesce((select least(boss_private.bucks_available(w.id,c.organization_id),(boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint)from public.boss_bucks_wallets w where w.household_id=c.household_id and w.currency=c.currency and boss_private.bucks_charge_authorized(actor,w.id,c.id)),0),
 'routes',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'account_id',r.account_id,'provider',a.provider,'environment',a.environment,'card',boss_private.rails_account_ready(a.id,c.organization_id,'card',c.currency),'ach',boss_private.rails_account_ready(a.id,c.organization_id,'ach',c.currency)))from public.payment_routing_revisions r join public.processing_accounts a on a.id=r.account_id where boss_private.rails_route_charge(r.id,c.id)and(boss_private.rails_account_ready(a.id,c.organization_id,'card',c.currency)or boss_private.rails_account_ready(a.id,c.organization_id,'ach',c.currency))),'[]')))
 from(select *from public.charges where(org is null or organization_id=org)and(query->>'charge_id'is null or id=(query->>'charge_id')::uuid)and boss_private.rails_charge_authorized(actor,id)order by id limit 50)c),'[]'),
 'checkouts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'currency',currency,'principal_minor',principal_minor,'bucks_minor',bucks_minor,'external_minor',external_minor,'method',method,'state',state,'expires_at',expires_at,'receipt',(select boss_private.rails_receipt(payment_id)from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null),'payment_success_at',(select received_at from public.payments where id=(select payment_id from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null))))from(select *from public.payment_checkouts where actor_person_id=actor and(org is null or organization_id=org)order by created_at desc,id limit 50)c),'[]'),
 'consents',coalesce((select jsonb_agg(jsonb_build_object('id',id,'method_id',method_id,'plan_id',plan_id,'starts_at',starts_at,'ends_at',ends_at,'revoked',revoked_at is not null,'execution','inactive'))from(select *from public.payment_execution_consents where person_id=actor order by created_at desc,id limit 50)c),'[]'),
 'saved_methods',coalesce((select jsonb_agg(jsonb_build_object('id',id,'method',method,'brand',brand,'last_four',last_four,'expires_month',expires_month,'expires_year',expires_year,'revoked',revoked_at is not null))from(select *from public.saved_payment_methods where person_id=actor order by created_at desc,id limit 50)m),'[]'));
 else raise exception'Invalid payment view'using errcode='PT422';end if;
 return boss_private.bucks_safe_money_json(result);
exception when invalid_text_representation then raise exception'Invalid payment filter'using errcode='PT422';end$$;

create function boss_private.rails_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;action text;request uuid;i jsonb;org uuid;result jsonb;prior boss_private.payment_requests;id uuid;c public.payment_checkouts;a public.processing_accounts;scope text;scopeid uuid;revision bigint;amount bigint;remaining bigint;source record;take bigint;currency text;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();if actor is null then raise exception'Authentication required'using errcode='PT401';end if;
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);action:=command->>'action';i:=command->'input';request:=boss_private.athlete_uuid(command,'request_id');
 if action in('method.revoke','consent.create','consent.revoke')then return boss_private.rails_consent_command(actor,command);end if;
 if action='checkout.prepare'then return boss_private.rails_prepare(actor,command);end if;
 if action='refund.prepare'then return boss_private.rails_refund_prepare(actor,command);end if;
 if action='checkout.cancel'then
 perform boss_private.athlete_input(i,array['checkout_id'],array['checkout_id']);c:=boss_private.rails_checkout_fence((i->>'checkout_id')::uuid);
 if c.actor_person_id is distinct from actor or c.state<>'ready' or exists(select 1 from public.provider_operations where checkout_id=c.id and dispatched_at is not null)then raise exception'Submitted attempts require reviewed reconciliation'using errcode='PT409';end if;
 update public.payment_checkouts set state='canceled'where payment_checkouts.id=c.id;insert into public.payment_checkout_events(checkout_id,kind)values(c.id,'canceled');return jsonb_build_object('state','canceled');
 end if;
 org:=(i->>'organization_id')::uuid;
 if action not in('account.create','account.disable','route.create','route.disable','policy.create','settlement.request','settlement.cancel')then raise exception'Unknown payment action'using errcode='PT422';end if;
 if not boss_private.rails_role(actor,case when action like'settlement.%'then'settlements.manage'else'payments.provider_manage'end,org)then raise exception'Access denied'using errcode='PT403';end if;
 perform boss_private.rails_fence(actor,org);perform boss_private.games_require_live_auth();
 if not boss_private.rails_role(actor,case when action like'settlement.%'then'settlements.manage'else'payments.provider_manage'end,org)then raise exception'Access denied'using errcode='PT403';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-payment-request:'||request,0));select *into prior from boss_private.payment_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command<>command then raise exception'Request replay conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true}'::jsonb;end if;
 if action='account.create'then
 perform boss_private.athlete_input(i,array['organization_id','provider','environment','name','country','currencies','merchant_owner','merchant_reference','settlement_mode','statement_descriptor'],array['organization_id','provider','environment','name','country','currencies','merchant_owner','merchant_reference','settlement_mode']);
 -- Draft-only. Private binding verification and account activation cannot be
 -- performed by a browser or by supplying a secret/handle through this command.
 if i->>'merchant_owner'='platform'and not exists(select 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id where ra.person_id=actor and ra.scope_type='platform'and ra.status='active'and ra.starts_at<=clock_timestamp()and(ra.ends_at is null or ra.ends_at>clock_timestamp())and r.key in('platform_administrator','super_administrator'))then raise exception'Platform merchant authority required'using errcode='PT403';end if;
 insert into public.processing_accounts(organization_id,provider,environment,name,country,currencies,merchant_owner,merchant_reference,settlement_mode,statement_descriptor,created_by)
 values(org,i->>'provider',i->>'environment',i->>'name',i->>'country',array(select jsonb_array_elements_text(i->'currencies')),i->>'merchant_owner',i->>'merchant_reference',i->>'settlement_mode',i->>'statement_descriptor',actor)returning processing_accounts.id into id;
 elsif action='account.disable'then
 perform boss_private.athlete_input(i,array['organization_id','account_id'],array['organization_id','account_id']);
 update public.processing_accounts set status='disabled',version=version+1,updated_at=clock_timestamp()where organization_id=org and processing_accounts.id=(i->>'account_id')::uuid returning processing_accounts.id into id;
 if id is null then raise exception'Access denied'using errcode='PT403';end if;
 elsif action='route.create'then
 perform boss_private.athlete_input(i,array['organization_id','account_id','purpose','currency','scope_type','scope_id'],array['organization_id','account_id','purpose','currency','scope_type','scope_id']);
 select *into a from public.processing_accounts where processing_accounts.id=(i->>'account_id')::uuid and organization_id=org;
 if a.id is null or a.status<>'active' or not exists(select 1 from boss_private.processing_bindings where account_id=a.id and revoked_at is null and verified_environment=a.environment and verified_merchant_reference=a.merchant_reference)
 or not(i->>'currency'=any(a.currencies))then raise exception'Verified exact account required'using errcode='PT409';end if;
 scope:=i->>'scope_type';scopeid:=(i->>'scope_id')::uuid;
 if not(scope='organization'and scopeid=org or scope='team'and exists(select 1 from public.teams where teams.id=scopeid and organization_id=org and status='active')
 or scope='unit'and exists(select 1 from public.organization_units where organization_units.id=scopeid and organization_id=org and status='active')
 or scope='campaign'and i->>'purpose'='fundraising'and exists(select 1 from public.fundraising_campaigns where fundraising_campaigns.id=scopeid and organization_id=org))then raise exception'Exact routing scope required'using errcode='PT403';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-payment-route:'||org||':'||(i->>'purpose')||':'||(i->>'currency')||':'||scope||':'||scopeid,0));
 select coalesce(max(r.revision),0)+1 into revision from public.payment_routing_revisions r where organization_id=org and purpose=i->>'purpose'and r.currency=i->>'currency'and scope_type=scope and scope_id=scopeid;
 insert into public.payment_routing_revisions(organization_id,account_id,purpose,currency,scope_type,scope_id,revision,starts_at,created_by)values(org,a.id,i->>'purpose',i->>'currency',scope,scopeid,revision,clock_timestamp(),actor)returning payment_routing_revisions.id into id;
 insert into public.payment_routing_events(routing_id,state,actor_id)values(id,'active',actor);
 elsif action='route.disable'then
 perform boss_private.athlete_input(i,array['organization_id','routing_id'],array['organization_id','routing_id']);
 select r.id into id from public.payment_routing_revisions r where r.id=(i->>'routing_id')::uuid and organization_id=org;
 if id is null then raise exception'Access denied'using errcode='PT403';end if;insert into public.payment_routing_events(routing_id,state,actor_id)values(id,'disabled',actor);
 elsif action='policy.create'then
 perform boss_private.athlete_input(i,array['organization_id','purpose','currency','organization_basis_points','platform_basis_points','product_cost_basis_points','processor_fee_owner','availability_seconds','request_target_seconds','estimated_processor_basis_points','estimated_processor_flat_minor'],array['organization_id','purpose','currency','organization_basis_points','platform_basis_points','product_cost_basis_points','processor_fee_owner','availability_seconds']);
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-policy:'||org||':'||(i->>'purpose')||':'||(i->>'currency'),0));
 select coalesce(max(p.revision),0)+1 into revision from public.settlement_policy_revisions p where organization_id=org and purpose=i->>'purpose'and p.currency=i->>'currency';
 insert into public.settlement_policy_revisions(organization_id,purpose,currency,revision,organization_basis_points,platform_basis_points,product_cost_basis_points,processor_fee_owner,availability_seconds,request_target_seconds,estimated_processor_basis_points,estimated_processor_flat_minor,created_by)
 values(org,i->>'purpose',i->>'currency',revision,(i->>'organization_basis_points')::int,(i->>'platform_basis_points')::int,(i->>'product_cost_basis_points')::int,i->>'processor_fee_owner',(i->>'availability_seconds')::int,(i->>'request_target_seconds')::int,(i->>'estimated_processor_basis_points')::int,(i->>'estimated_processor_flat_minor')::bigint,actor)returning settlement_policy_revisions.id into id;
 elsif action='settlement.request'then
 perform boss_private.athlete_input(i,array['organization_id','currency','amount_minor'],array['organization_id','currency','amount_minor']);currency:=i->>'currency';amount:=boss_private.rails_amount(i,'amount_minor');
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-org:'||org||':'||currency,0));
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-request:'||org||':'||currency,0));
 if not boss_private.rails_feature(org,'settlement')or amount>boss_private.rails_payable(org,currency)then raise exception'Request exceeds available payable'using errcode='PT409';end if;
 insert into public.settlement_requests(organization_id,currency,amount_minor,requested_by,request_id)values(org,currency,amount,actor,request)returning settlement_requests.id into id;remaining:=amount;
 for source in select s.*from public.settlement_sources s where organization_id=org and s.currency=i->>'currency' and settlement_mode='platform_managed'and available_at<=clock_timestamp()
 and exists(select 1 from public.settlement_events where payment_id=s.payment_id and kind='settled')order by available_at,payment_id limit 100 loop
 take:=least(remaining,boss_private.rails_source_payable(source.payment_id)-coalesce((select sum(ri.amount_minor)from public.settlement_request_items ri join public.settlement_requests sr on sr.id=ri.request_id where ri.payment_id=source.payment_id and sr.state in('requested','review','scheduled','paid','partially_paid')),0));
 if take<=0 then continue;end if;insert into public.settlement_request_items(request_id,payment_id,amount_minor)values(id,source.payment_id,take);remaining:=remaining-take;exit when remaining=0;end loop;
 if remaining<>0 then raise exception'Bounded payable changed'using errcode='PT409';end if;
 insert into public.settlement_request_history(request_id,state,actor_id)values(id,'requested',actor);
 else
 perform boss_private.athlete_input(i,array['organization_id','settlement_request_id'],array['organization_id','settlement_request_id']);
 update public.settlement_requests set state='canceled'where organization_id=org and settlement_requests.id=(i->>'settlement_request_id')::uuid and state in('requested','review')returning settlement_requests.id into id;
 if id is null then raise exception'Request is no longer cancelable'using errcode='PT409';end if;insert into public.settlement_request_history(request_id,state,actor_id)values(id,'canceled',actor);
 end if;
 result:=jsonb_build_object('action',action,'id',id,'replayed',false);insert into boss_private.payment_requests(request_id,actor_id,command,result)values(request,actor,command,result);
 perform boss_private.rails_audit(actor,org,'payment.'||action,id,request);return result;
exception when invalid_text_representation or check_violation or not_null_violation or numeric_value_out_of_range then raise exception'Invalid payment input'using errcode='PT422';end$$;

create function public.boss_payments_read(query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.rails_read(query)$$;
create function public.boss_payments_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.rails_mutate(command)$$;
revoke all on function public.boss_payments_read(jsonb),public.boss_payments_mutate(jsonb)from public,anon,authenticated,service_role;
grant execute on function public.boss_payments_read(jsonb),public.boss_payments_mutate(jsonb)to authenticated;
-- Exact stable entry points only. NOLOGIN infrastructure remains unconfigured.
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'rails_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;
grant execute on function boss_private.rails_read(jsonb),boss_private.rails_mutate(jsonb)to authenticated;
-- Identity/source integrity of settlement request state caches.
create function boss_private.rails_request_guard()returns trigger language plpgsql set search_path=''as $$begin
 if tg_op='DELETE'or to_jsonb(new)-'state' is distinct from to_jsonb(old)-'state' or new.state not in('requested','review','canceled')then raise exception'Outbound payout rail unavailable; request history is immutable'using errcode='23514';end if;return new;
end$$;
revoke all on function boss_private.rails_request_guard()from public,anon,authenticated,service_role,boss_payment_worker;
create trigger rails_settlement_request_guard before update or delete on public.settlement_requests for each row execute function boss_private.rails_request_guard();

create function boss_private.rails_worker_claim(checkout uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare claim jsonb;c public.payment_checkouts;o public.provider_operations;a public.processing_accounts;r public.payment_refund_requests;original public.provider_operations;begin
 select *into r from public.payment_refund_requests where id=checkout;
 if r.id is not null then
 claim:=boss_private.rails_refund_dispatch(r.id);select *into o from public.provider_operations where id=r.operation_id;select *into c from public.payment_checkouts where id=o.checkout_id;select *into a from public.processing_accounts where id=o.account_id;select *into original from public.provider_operations where id=o.parent_operation_id;
 if o.state in('succeeded','failed')then return null;end if;
 return jsonb_build_object('operation_id',o.id,'generation',o.dispatched_at,'first_dispatch',claim->'first_dispatch','transaction_reference',o.provider_transaction_reference,
 'account',jsonb_build_object('id',a.id,'organization_id',a.organization_id,'provider',a.provider,'environment',a.environment,'merchant_reference',a.merchant_reference,'country',a.country,'currency',c.currency,'capabilities',a.capabilities,'verified',true),
 'command',jsonb_build_object('kind','refund','transaction_reference',original.provider_transaction_reference,'request_reference',o.provider_request_reference,'amount_minor',o.amount_minor::text,'method',c.method,'currency',c.currency));end if;
 claim:=boss_private.rails_dispatch(checkout);select *into c from public.payment_checkouts where id=checkout;
 select *into o from public.provider_operations where id=(claim->>'operation_id')::uuid;select *into a from public.processing_accounts where id=c.account_id;
 if c.state in('failed','canceled','expired')then return null;end if;
 return jsonb_build_object('operation_id',o.id,'generation',o.dispatched_at,'first_dispatch',claim->'first_dispatch','transaction_reference',o.provider_transaction_reference,
 'account',jsonb_build_object('id',a.id,'organization_id',a.organization_id,'provider',a.provider,'environment',a.environment,'merchant_reference',a.merchant_reference,'country',a.country,'currency',c.currency,'capabilities',a.capabilities,'verified',true),
 'command',jsonb_build_object('kind',o.kind,'request_reference',o.provider_request_reference,'amount_minor',o.amount_minor::text,'method',c.method,'currency',c.currency));
end$$;
create function boss_private.rails_worker_finish(checkout uuid,operation uuid,generation timestamptz,result jsonb,event_reference text,digest text)returns boolean language plpgsql volatile security definer set search_path=''as $$
declare c public.payment_checkouts;o public.provider_operations;kind text;metadata jsonb:='{}';observed timestamptz;r public.payment_refund_requests;p uuid;ev uuid;principal bigint;allocations jsonb;begin
 select *into r from public.payment_refund_requests where id=checkout;
 if r.id is not null then select *into o from public.provider_operations where id=r.operation_id;if o.id<>operation or o.dispatched_at is distinct from generation then return false;end if;
 perform boss_private.athlete_input(result,array['state','transaction_reference','amount_minor','currency','occurred_at','risk_code'],array['state']);
 if result->>'state'='refunded'and(result->>'amount_minor'is distinct from o.amount_minor::text or result->>'currency'is distinct from o.currency)then raise exception'Exact refund amount and currency required'using errcode='PT422';end if;
 select e.occurred_at into observed from public.provider_event_evidence e where e.account_id=o.account_id and e.event_reference=rails_worker_finish.event_reference;
 perform boss_private.rails_refund_receive(r.id,event_reference,case result->>'state'when'refunded'then'refunded'when'declined'then'failed'when'failed'then'failed'else'unknown'end,result->>'transaction_reference',o.amount_minor,coalesce(result->>'currency',o.currency),coalesce((result->>'occurred_at')::timestamptz,observed,clock_timestamp()),digest);return true;end if;
 c:=boss_private.rails_checkout_fence(checkout);select *into o from public.provider_operations where id=operation and checkout_id=c.id for update;
 if o.id is null or o.dispatched_at is distinct from generation then return false;end if;
 perform boss_private.athlete_input(result,array['state','transaction_reference','amount_minor','currency','occurred_at','risk_code'],array['state']);
 kind:=case result->>'state'when'declined'then'failed'when'failed'then'failed'when'authorized'then'authorized'when'captured'then'captured'when'settled'then'settled'when'ach_pending'then'ach_pending'when'returned'then'returned'when'voided'then'voided'else'unknown'end;
 if kind='failed'then metadata:=jsonb_build_object('failure_contract',case result->>'state'when'declined'then'definitive_decline'else'definitive_failure'end);end if;
 if result?'risk_code'then if result->>'risk_code'!~'^[A-Za-z0-9_-]{1,30}$'then raise exception'Invalid safe risk metadata'using errcode='PT422';end if;metadata:=metadata||jsonb_build_object('risk_code',result->>'risk_code');end if;
 select e.occurred_at into observed from public.provider_event_evidence e where e.account_id=c.account_id and e.event_reference=rails_worker_finish.event_reference;
 perform boss_private.rails_receive(c.id,event_reference,kind,result->>'transaction_reference',case when kind in('unknown','failed')then o.amount_minor else(result->>'amount_minor')::bigint end,
 coalesce(result->>'currency',o.currency),coalesce((result->>'occurred_at')::timestamptz,observed,clock_timestamp()),digest,metadata);
 if kind in('returned','voided')then
 select payment_id into p from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null;select id into ev from public.provider_event_evidence where account_id=c.account_id and provider_event_evidence.event_reference=rails_worker_finish.event_reference;
 if p is not null and not exists(select 1 from public.external_payment_corrections where event_id=ev)then
 if exists(select 1 from public.external_payment_corrections where original_payment_id=p)then insert into public.payment_review_cases(checkout_id,event_id,reason)values(c.id,ev,'contradictory_status')on conflict do nothing;
 else
 select coalesce(jsonb_agg(jsonb_build_object('allocation_id',id,'amount_minor',amount_minor)),'[]')into allocations from public.payment_allocations where payment_id=p and status='applied';
 principal:=c.principal_minor-c.bucks_minor;perform boss_private.rails_external_correct(p,ev,case kind when'returned'then'ach_return'else'void'end,principal,allocations);end if;end if;end if;return true;
end$$;
revoke all on function boss_private.rails_worker_claim(uuid),boss_private.rails_worker_finish(uuid,uuid,timestamptz,jsonb,text,text)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_private.rails_worker_claim(uuid),boss_private.rails_worker_finish(uuid,uuid,timestamptz,jsonb,text,text)to boss_payment_worker;
-- Cover every new foreign-key prefix, including composite tenant lineage.
create index payment_checkout_events_operation_idx on public.payment_checkout_events(operation_id);
create index payment_eligibility_commits_org_checkout_idx on public.payment_eligibility_commits(organization_id,checkout_id);
create index settlement_sources_org_payment_idx on public.settlement_sources(organization_id,payment_id);

-- Finite private batch import. Only authoritative, normalized query results are
-- accepted. Missing data creates review evidence, never an automatic release.
create function boss_private.rails_reconcile_batch(account uuid,request uuid,from_at timestamptz,to_at timestamptz,items jsonb)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare a public.processing_accounts;run public.payment_reconciliation_runs;o public.provider_operations;x jsonb;state text;ev uuid;p uuid;c public.payment_checkouts;received jsonb;begin
 select *into a from public.processing_accounts where id=account;
 if a.id is null or not a.capabilities@>array['settlement_query']or jsonb_typeof(items)is distinct from'array'or jsonb_array_length(items)>100 then raise exception'Bounded certified reconciliation required'using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-payment-reconcile:'||request,0));
 select *into run from public.payment_reconciliation_runs where request_id=request;
 if run.id is not null then if run.account_id<>account or run.from_at<>from_at or run.to_at<>to_at or run.command_digest<>encode(sha256(convert_to(items::text,'UTF8')),'hex')then raise exception'Reconciliation replay conflict'using errcode='PT409';end if;return run.id;end if;
 insert into public.payment_reconciliation_runs(account_id,request_id,from_at,to_at,command_digest)values(account,request,from_at,to_at,encode(sha256(convert_to(items::text,'UTF8')),'hex'))returning *into run;
 for x in select value from jsonb_array_elements(items)loop
 perform boss_private.athlete_input(x,array['request_reference','transaction_reference','event_reference','state','amount_minor','currency','occurred_at','processor_fee_minor','batch_reference','digest','failure_contract'],array['request_reference','event_reference','state','digest']);
 if x->>'request_reference'!~'^[a-z0-9]{20}$'or x->>'event_reference'!~'^[A-Za-z0-9_.:-]{1,200}$'or x->>'digest'!~'^[a-f0-9]{64}$'then raise exception'Invalid safe reconciliation identity'using errcode='PT422';end if;
 select *into o from public.provider_operations where account_id=account and provider_request_reference=x->>'request_reference';
 state:='pending';ev:=null;p:=null;
 if o.id is null then state:='missing_boss';
 elsif x->>'state'='missing_provider'then state:='missing_provider';
 elsif x->>'currency'is distinct from o.currency then state:='mismatch';
 elsif (x->>'amount_minor')::bigint is distinct from o.amount_minor then state:='amount_mismatch';
 elsif x->>'state'not in('unknown','authorized','captured','ach_pending','settled','failed')then state:='mismatch';
 elsif o.kind not in('sale','authorize')then state:='settlement_mismatch';
 else
 c:=boss_private.rails_checkout_fence(o.checkout_id);
 received:=boss_private.rails_receive(c.id,x->>'event_reference',x->>'state',x->>'transaction_reference',o.amount_minor,o.currency,(x->>'occurred_at')::timestamptz,x->>'digest',
 jsonb_strip_nulls(jsonb_build_object('processor_fee_minor',x->'processor_fee_minor','batch_reference',x->'batch_reference','failure_contract',x->'failure_contract')));
 select id into ev from public.provider_event_evidence where account_id=account and event_reference=x->>'event_reference';
 select payment_id into p from public.external_payment_tenders where operation_id=o.id and original_payment_id is null;
 state:=case when x->>'state'='failed'then'matched'when p is not null then'matched'else'pending'end;
 if x->>'state'='settled'and p is not null then
 if not x?'processor_fee_minor'then state:='fee_mismatch';else received:=boss_private.rails_settlement_match(p,ev,(x->>'processor_fee_minor')::bigint);if received->>'state'<>'settled'then state:='settlement_mismatch';end if;end if;
 end if;end if;
 insert into public.payment_reconciliation_items(run_id,operation_id,event_id,provider_reference,state)values(run.id,o.id,ev,coalesce(x->>'transaction_reference',x->>'request_reference'),state);
 end loop;
 perform boss_private.rails_audit(null,a.organization_id,'payment.reconciliation.completed',run.id,request,jsonb_build_object('item_count',jsonb_array_length(items)));return run.id;
end$$;
-- Configurable review SLA is an explicit finite configuration value, not a
-- default financial expiry. It changes review state but never releases a hold.
create function boss_private.rails_review_due(checkout uuid)returns boolean language plpgsql volatile security definer set search_path=''as $$
declare c public.payment_checkouts;o public.provider_operations;seconds integer;begin
 c:=boss_private.rails_checkout_fence(checkout);select *into o from public.provider_operations where checkout_id=c.id and kind in('sale','authorize');
 select(configuration->>'provider_review_seconds')::integer into seconds from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id=c.organization_id and m.key='payments'and om.status='active';
 if seconds is null or seconds not between 60 and 2678400 or o.dispatched_at is null or o.dispatched_at+make_interval(secs=>seconds)>clock_timestamp()or not boss_private.rails_hold(c.id)or c.state='review_required'then return false;end if;
 update public.payment_checkouts set state='review_required'where id=c.id;insert into public.payment_checkout_events(checkout_id,kind,operation_id)values(c.id,'review_required',o.id);
 perform boss_private.rails_audit(null,c.organization_id,'payment.review.required',c.id,null,jsonb_build_object('operation_id',o.id));return true;
end$$;

create function boss_private.rails_receipt(payment uuid)returns jsonb language sql volatile security definer set search_path=''as $$
 select jsonb_build_object('payment_id',p.id,'organization_id',p.organization_id,'organization',o.name,'amount_minor',p.amount_minor,'currency',p.currency,'method',p.method,'payment_success_at',p.received_at,
 'principal_minor',c.principal_minor-c.bucks_minor,'donor_fee_minor',c.donor_covered_fee_minor,'platform_fee_minor',c.platform_fee_minor,'purpose',t.purpose,
 'refunded_minor',(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=p.id),
 'allocations',coalesce((select jsonb_agg(jsonb_build_object('charge_id',pa.charge_id,'amount_minor',pa.amount_minor))from public.payment_allocations pa where pa.payment_id=p.id),'[]'),
 'organization_settlement',case when exists(select 1 from public.settlement_events where payment_id=p.id and kind='settled')then'provider_settled'else'pending'end)
 from public.payments p join public.external_payment_tenders t on t.payment_id=p.id and t.original_payment_id is null join public.payment_checkouts c on c.id=t.checkout_id join public.organizations o on o.id=p.organization_id where p.id=payment
$$;
-- Verified provider profile registration is private. A provider/account/owner
-- match is compulsory; profile identifiers never appear in family projections.
create function boss_private.rails_profile_register(checkout uuid,customer text,profile text,brand text,last_four text)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare c public.payment_checkouts;p uuid;donor uuid;existing public.saved_payment_methods;begin
 c:=boss_private.rails_checkout_fence(checkout);
 if c.state not in('completed','partially_refunded')or customer!~'^[A-Za-z0-9_.:-]{1,100}$'or profile!~'^[A-Za-z0-9_.:-]{1,100}$'or brand!~'^[A-Za-z0-9_-]{1,30}$'or last_four!~'^[0-9]{4}$'
 or not exists(select 1 from public.processing_accounts where id=c.account_id and capabilities@>array['saved_profile'])then raise exception'Verified profile context unavailable'using errcode='PT422';end if;
 if c.actor_person_id is null then select donor_id into donor from public.fundraising_intents where id=c.intent_id;end if;
 select *into existing from public.saved_payment_methods where account_id=c.account_id and customer_reference=customer and profile_reference=profile;
 if existing.id is not null then if existing.person_id is distinct from c.actor_person_id or existing.donor_id is distinct from donor then raise exception'Profile owner conflict'using errcode='PT409';end if;return existing.id;end if;
 insert into public.saved_payment_methods(account_id,person_id,donor_id,customer_reference,profile_reference,method,brand,last_four)values(c.account_id,c.actor_person_id,donor,customer,profile,c.method,brand,last_four)returning id into p;
 perform boss_private.rails_audit(c.actor_person_id,c.organization_id,'payment.profile.verified',p,null);return p;
end$$;
revoke all on function boss_private.rails_reconcile_batch(uuid,uuid,timestamptz,timestamptz,jsonb),boss_private.rails_review_due(uuid),boss_private.rails_receipt(uuid),boss_private.rails_profile_register(uuid,text,text,text,text)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_private.rails_reconcile_batch(uuid,uuid,timestamptz,timestamptz,jsonb),boss_private.rails_review_due(uuid),boss_private.rails_profile_register(uuid,text,text,text,text)to boss_payment_worker;

create function boss_private.rails_rate(p_context text,p_limit integer)returns void language plpgsql volatile security definer set search_path=''as $$declare attempts integer;begin
 insert into boss_private.fundraising_rate_windows(context,window_at,attempts)values('payments:'||p_context,date_trunc('minute',clock_timestamp()),1)
 on conflict(context,window_at)do update set attempts=fundraising_rate_windows.attempts+1 returning fundraising_rate_windows.attempts into attempts;
 if attempts>p_limit then raise exception'Please try again shortly'using errcode='PT429';end if;
end$$;
-- Guest authority is only the original unguessable contribution capability.
-- No organization financial projection or provider binding crosses this RPC.
create function boss_private.rails_guest(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare action text;i jsonb;cap text;request uuid;ctx jsonb;intent public.fundraising_intents;c public.payment_checkouts;r public.payment_routing_revisions;policy public.settlement_policy_revisions;org uuid;fee bigint:=0;h text;begin
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);i:=command->'input';action:=command->>'action';request:=(command->>'request_id')::uuid;
 perform boss_private.athlete_input(i,array['path','capability','method'],array['path','capability']);
 if action not in('prepare','status','cancel')or i->>'capability'!~'^[a-f0-9]{64}$'then raise exception'Invalid contribution capability'using errcode='PT422';end if;
 cap:=encode(sha256(convert_to(i->>'capability','UTF8')),'hex');h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');
 select *into intent from public.fundraising_intents where capability_digest=cap;
 if intent.id is null then raise exception'Contribution unavailable'using errcode='PT404';end if;
 select organization_id into org from public.fundraising_campaigns where id=intent.campaign_id;
 perform pg_advisory_xact_lock(hashtextextended('boss-payment-guest:'||intent.id,0));
 select *into c from public.payment_checkouts where intent_id=intent.id;
 if action='prepare'and c.id is not null then if c.request_id<>request or c.command_hash<>h then raise exception'Original attempt must be resolved'using errcode='PT409';end if;
 return jsonb_build_object('checkout_id',c.id,'state',c.state,'replayed',true);end if;
 if action='prepare'then
 ctx:=boss_private.fundraising_public_context(i->>'path');
 if(ctx->>'campaign_id')::uuid<>intent.campaign_id or(ctx->>'fundraiser_id')::uuid is distinct from intent.fundraiser_id or i->>'method'not in('card','ach')or intent.expires_at<=clock_timestamp()then raise exception'Contribution eligibility ended'using errcode='PT409';end if;
 select *into r from public.payment_routing_revisions where organization_id=org and purpose='fundraising'and currency=intent.currency and boss_private.rails_route_current(id)
 and(case scope_type when'campaign'then scope_id=intent.campaign_id when'organization'then scope_id=org else false end)
 and boss_private.rails_account_ready(account_id,org,i->>'method',intent.currency)order by case scope_type when'campaign'then 0 else 1 end,revision desc limit 1;
 if r.id is null then raise exception'External payment is unavailable'using errcode='PT409';end if;
 perform boss_private.rails_fence(null,org);select *into intent from public.fundraising_intents where id=intent.id for update;
 if intent.expires_at<=clock_timestamp()then raise exception'Contribution eligibility ended'using errcode='PT409';end if;
 select *into policy from public.settlement_policy_revisions where organization_id=org and purpose='fundraising'and currency=intent.currency order by revision desc limit 1;
 if intent.fee_cover then if policy.estimated_processor_basis_points is null then raise exception'Fee-cover estimate unavailable'using errcode='PT409';end if;
 fee:=ceil(intent.amount_minor::numeric*policy.estimated_processor_basis_points/10000)::bigint+policy.estimated_processor_flat_minor;end if;
 perform boss_private.rails_rate('guest:'||intent.campaign_id,120);
 insert into public.payment_checkouts(organization_id,intent_id,purpose,currency,account_id,routing_id,policy_id,method,principal_minor,external_minor,donor_covered_fee_minor,request_id,command_hash,capability_digest,expires_at)
 values(org,intent.id,'fundraising',intent.currency,r.account_id,r.id,policy.id,i->>'method',intent.amount_minor,intent.amount_minor+fee,fee,request,h,cap,least(intent.expires_at,clock_timestamp()+interval'10 minutes'))returning *into c;
 insert into public.payment_checkout_events(checkout_id,kind)values(c.id,'ready');perform boss_private.rails_audit(null,org,'payment.checkout.prepared',c.id,request,jsonb_build_object('intent_id',intent.id,'principal_minor',intent.amount_minor,'donor_fee_minor',fee));
 elsif c.id is null then raise exception'Attempt unavailable'using errcode='PT404';
 elsif action='cancel'then c:=boss_private.rails_checkout_fence(c.id);if c.state<>'ready'or exists(select 1 from public.provider_operations where checkout_id=c.id and dispatched_at is not null)then raise exception'Submitted attempts require reconciliation'using errcode='PT409';end if;
 update public.payment_checkouts set state='canceled'where id=c.id;insert into public.payment_checkout_events(checkout_id,kind)values(c.id,'canceled');c.state:='canceled';end if;
 return boss_private.bucks_safe_money_json(jsonb_build_object('checkout_id',c.id,'state',c.state,'method',c.method,'principal_minor',c.principal_minor,'donor_fee_minor',c.donor_covered_fee_minor,'external_minor',c.external_minor,'receipt',(select boss_private.rails_receipt(payment_id)from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null)));
end$$;
create function boss_fundraising_public.payments(command jsonb)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.rails_guest(command)$$;
create function public.boss_payments_support(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_fundraising_public.payments(command)$$;
revoke all on function boss_private.rails_rate(text,integer),boss_private.rails_guest(jsonb),public.boss_payments_support(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
revoke all on function boss_fundraising_public.payments(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_fundraising_public.payments(jsonb),public.boss_payments_support(jsonb)to anon,authenticated;

create function boss_private.rails_consent_command(actor uuid,command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare action text:=command->>'action';i jsonb:=command->'input';request uuid:=(command->>'request_id')::uuid;method public.saved_payment_methods;consent public.payment_execution_consents;plan public.payment_plans;prior boss_private.payment_requests;id uuid;org uuid;begin
 perform pg_advisory_xact_lock(hashtextextended('boss-payment-request:'||request,0));
 if not boss_private.rails_actor_current(actor)then raise exception'Authentication required'using errcode='PT401';end if;
 select *into prior from boss_private.payment_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command<>command then raise exception'Consent replay conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true}'::jsonb;end if;
 if action='method.revoke'then
 perform boss_private.athlete_input(i,array['method_id'],array['method_id']);select *into method from public.saved_payment_methods where saved_payment_methods.id=(i->>'method_id')::uuid and person_id=actor for update;
 if method.id is null then raise exception'Access denied'using errcode='PT403';end if;
 update public.saved_payment_methods set revoked_at=coalesce(revoked_at,clock_timestamp())where saved_payment_methods.id=method.id;
 update public.payment_execution_consents set revoked_at=coalesce(revoked_at,clock_timestamp())where method_id=method.id;id:=method.id;
 elsif action='consent.revoke'then
 perform boss_private.athlete_input(i,array['consent_id'],array['consent_id']);update public.payment_execution_consents set revoked_at=coalesce(revoked_at,clock_timestamp())where payment_execution_consents.id=(i->>'consent_id')::uuid and person_id=actor returning *into consent;
 if consent.id is null then raise exception'Access denied'using errcode='PT403';end if;id:=consent.id;select *into method from public.saved_payment_methods where saved_payment_methods.id=consent.method_id;
 elsif action='consent.create'then
 perform boss_private.athlete_input(i,array['method_id','plan_id','starts_at','ends_at','accepted'],array['method_id','plan_id','starts_at','accepted']);
 select *into method from public.saved_payment_methods where saved_payment_methods.id=(i->>'method_id')::uuid and person_id=actor and revoked_at is null for update;
 select *into plan from public.payment_plans where payment_plans.id=(i->>'plan_id')::uuid and status='active';
 if method.id is null or plan.id is null or i->>'accepted'<>'true'or not boss_private.rails_charge_authorized(actor,plan.charge_id)
 or not exists(select 1 from public.processing_accounts where processing_accounts.id=method.account_id and organization_id=plan.organization_id)then raise exception'Exact method and plan authority required'using errcode='PT403';end if;
 perform boss_private.rails_fence(actor,plan.organization_id);
 if not boss_private.rails_actor_current(actor)or not boss_private.rails_charge_authorized(actor,plan.charge_id)then raise exception'Access denied'using errcode='PT403';end if;
 insert into public.payment_execution_consents(person_id,method_id,plan_id,starts_at,ends_at)values(actor,method.id,plan.id,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz)returning payment_execution_consents.id into id;
 else raise exception'Invalid consent action'using errcode='PT422';end if;
 select organization_id into org from public.processing_accounts where processing_accounts.id=method.account_id;
 perform boss_private.rails_audit(actor,org,'payment.'||action,id,request);insert into boss_private.payment_requests(request_id,actor_id,command,result)values(request,actor,command,jsonb_build_object('action',action,'id',id,'state','inactive','replayed',false))returning result into prior.result;return prior.result;
end$$;
revoke all on function boss_private.rails_consent_command(uuid,jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
