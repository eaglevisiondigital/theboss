-- Finite flags: no provider, settlement, transfer or cashout capability.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.bucks_feature(uuid,text)'::regprocedure);
 d:=replace(d,'''charge_eligibility_preview'')','''charge_eligibility_preview'',''wallet_spending'',''charge_payments'',''split_tender'')');execute d;
 d:=pg_get_functiondef('boss_private.bucks_role(uuid,text,uuid)'::regprocedure);
 d:=replace(d,'''boss_bucks.policy_manage'')','''boss_bucks.policy_manage'',''boss_bucks.payment_reverse'')');execute d;
 d:=pg_get_functiondef('boss_private.bucks_module_configuration()'::regprocedure);
 d:=replace(d,'''charge_eligibility_preview'']','''charge_eligibility_preview'',''wallet_spending'',''charge_payments'',''split_tender'']');execute d;
 d:=pg_get_functiondef('boss_private.bucks_mutate(jsonb)'::regprocedure);
 d:=replace(d,'''charge_eligibility_preview'']','''charge_eligibility_preview'',''wallet_spending'',''charge_payments'',''split_tender'']');execute d;
 -- Existing offline allocation uniqueness must compare canonical UUIDs too.
 -- Mixed-case representations cannot split one charge into duplicate legs.
 d:=pg_get_functiondef('boss_private.registration_command(jsonb,uuid,uuid,boolean,uuid)'::regprocedure);
 if position('count(distinct allocation_item->>''charge_id'')'in d)=0 then raise exception'Offline allocation checkpoint mismatch';end if;
 d:=replace(d,'count(distinct allocation_item->>''charge_id'')','count(distinct (allocation_item->>''charge_id'')::uuid)');execute d;
end$$;

create function boss_private.bucks_payment_guardian(actor uuid,participant uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.registration_guardian(participant,'can_manage_payments')and exists(
 select 1 from public.participants p join public.people child on child.id=p.person_id and child.status='active'
 join public.guardian_relationships g on g.dependent_person_id=p.person_id and g.guardian_person_id=actor
 where p.id=participant and p.status='active'and g.can_manage_payments and g.authority_status='active'
 and g.verified_at<=clock_timestamp()and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp()))
$$;
create function boss_private.bucks_payment_features(org uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.bucks_feature(org,'wallet_spending')and boss_private.bucks_feature(org,'charge_payments')
 and boss_private.bucks_feature(org,'family_wallet')and boss_private.registration_feature(org,'fees')
 and exists(select 1 from public.organization_modules m join public.modules k on k.id=m.module_id and k.key='registration'and k.status='active'
 where m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
$$;
create function boss_private.bucks_payment_fence(actor uuid,org uuid,wallet uuid,household uuid)returns void language plpgsql volatile security definer set search_path=''as $$begin
 -- No wallet SHARE lock here: two spenders must not both upgrade that lock.
 perform 1 from public.organization_modules where organization_id=org and module_id in(select id from public.modules where key in('boss_bucks','registration'))order by id for share;
 perform boss_private.bucks_fence(actor,org,null,household);
 perform 1 from public.people where id=actor or id in(select person_id from public.household_memberships where household_id=household)order by id for share;
 perform 1 from public.user_accounts where person_id=actor for share;
 perform 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=auth.uid()for share;
end$$;
create function boss_private.bucks_charge_authorized(actor uuid,wallet uuid,charge uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.charges c join public.boss_bucks_wallets w on w.id=wallet
 join public.participants p on p.id=c.participant_id where c.id=charge and c.household_id=w.household_id and c.currency=w.currency
 and c.status='active'and boss_private.bucks_payment_features(c.organization_id)
 and boss_private.bucks_accessible(actor,w.id,true)and boss_private.bucks_guardian(actor,p.person_id,w.household_id)
 and boss_private.bucks_payment_guardian(actor,p.id))
$$;

create function boss_private.bucks_spend(actor uuid,command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb:=command->'input';request uuid:=(command->>'request_id')::uuid;w public.boss_bucks_wallets;c public.charges;org uuid;
 x jsonb;total bigint:=0;amount bigint;payment uuid:=gen_random_uuid();allocation uuid;allocation_ids uuid[]:='{}';allocation_left bigint[]:='{}';allocation_index integer:=1;
 prior boss_private.bucks_requests;result jsonb;receipt jsonb;g record;j uuid;take bigint;chunk bigint;remaining bigint;ordinal integer:=0;begin
 if jsonb_typeof(i)is distinct from'object'or exists(select 1 from jsonb_object_keys(i)k where k<>all(array['wallet_id','organization_id','currency','amount_minor','allocations','checkout_id']))
 or not(i?&array['wallet_id','organization_id','currency','amount_minor','allocations'])
 or jsonb_typeof(i->'allocations')is distinct from'array'or jsonb_array_length(i->'allocations')not between 1 and 50
 or coalesce(i->>'amount_minor','')!~'^[1-9][0-9]{0,9}$'then raise exception'Invalid payment fields'using errcode='PT422';end if;
 amount:=(i->>'amount_minor')::bigint;org:=(i->>'organization_id')::uuid;
 if amount>1000000000 or org is null then raise exception'Invalid payment fields'using errcode='PT422';end if;
 select *into w from public.boss_bucks_wallets where id=(i->>'wallet_id')::uuid;
 if w.id is null or i->>'currency' is distinct from w.currency then raise exception'Access denied'using errcode='PT403';end if;
 if not boss_private.bucks_accessible(actor,w.id,true)or not boss_private.bucks_payment_features(org)then raise exception'Access denied'using errcode='PT403';end if;
 for x in select value from jsonb_array_elements(i->'allocations')loop
 if jsonb_typeof(x)is distinct from'object'or exists(select 1 from jsonb_object_keys(x)k where k<>all(array['charge_id','amount_minor']))
 or not(x?&array['charge_id','amount_minor'])or coalesce(x->>'amount_minor','')!~'^[1-9][0-9]{0,9}$'or(x->>'amount_minor')::bigint>1000000000 then raise exception'Invalid allocation fields'using errcode='PT422';end if;
 total:=total+(x->>'amount_minor')::bigint;end loop;
 if total<>amount or(select count(distinct(value->>'charge_id')::uuid)from jsonb_array_elements(i->'allocations'))<>jsonb_array_length(i->'allocations')then raise exception'Allocation sum mismatch'using errcode='PT422';end if;
 for x in select value from jsonb_array_elements(i->'allocations')loop
 if not boss_private.bucks_charge_authorized(actor,w.id,(x->>'charge_id')::uuid)then raise exception'Access denied'using errcode='PT403';end if;end loop;
 perform boss_private.bucks_payment_fence(actor,org,w.id,w.household_id);
 for x in select value from jsonb_array_elements(i->'allocations')order by (value->>'charge_id')::uuid loop
 select *into c from public.charges where id=(x->>'charge_id')::uuid and organization_id=org for update;
 if c.id is null then raise exception'Access denied'using errcode='PT403';end if;
 update public.charges set status=status where id=c.id;end loop;
 perform boss_private.bucks_wallet_lock(w.id);
 perform 1 from public.boss_bucks_accounts where wallet_id=w.id and organization_id=org order by id for update;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.current_person_id()then raise exception'Authentication required'using errcode='PT401';end if;
 for x in select value from jsonb_array_elements(i->'allocations')order by (value->>'charge_id')::uuid loop
 if not boss_private.bucks_charge_authorized(actor,w.id,(x->>'charge_id')::uuid)then raise exception'Access denied'using errcode='PT403';end if;end loop;
 perform pg_advisory_xact_lock(hashtextextended('boss-bucks-request:'||request::text,0));
 select *into prior from boss_private.bucks_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command<>command then raise exception'Request conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true}'::jsonb;end if;
 for x in select value from jsonb_array_elements(i->'allocations')order by (value->>'charge_id')::uuid loop
 select *into c from public.charges where id=(x->>'charge_id')::uuid;
 if(boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint<(x->>'amount_minor')::bigint then raise exception'Payment exceeds current obligation'using errcode='PT409';end if;
 if not boss_private.bucks_feature(org,'split_tender')and((x->>'amount_minor')::bigint<>(boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint
 or exists(select 1 from public.payment_allocations where charge_id=c.id))then raise exception'Split tender disabled'using errcode='PT403';end if;end loop;
 if boss_private.bucks_available(w.id,org)<amount then raise exception'Available value changed'using errcode='PT409';end if;
 insert into public.payments(id,organization_id,method,amount_minor,currency,payer_person_id,received_at,reference,source_reference,recorded_by_person_id)
 values(payment,org,'boss_bucks',amount,w.currency,actor,clock_timestamp(),request::text,request::text,actor);
 insert into public.boss_bucks_tenders(payment_id,wallet_id,organization_id,currency,actor_person_id,request_id,checkout_id)
 values(payment,w.id,org,w.currency,actor,request,coalesce((i->>'checkout_id')::uuid,request));
 for x in select value from jsonb_array_elements(i->'allocations')order by (value->>'charge_id')::uuid loop
 insert into public.payment_allocations(organization_id,payment_id,charge_id,amount_minor)values(org,payment,(x->>'charge_id')::uuid,(x->>'amount_minor')::bigint)returning id into allocation;
 allocation_ids:=array_append(allocation_ids,allocation);allocation_left:=array_append(allocation_left,(x->>'amount_minor')::bigint);end loop;
 remaining:=amount;
 -- One grouped ledger query chooses at most 200 positive lots. Wallet fencing
 -- serializes all monetary writers; the selected grants are then locked.
 for g in with balances as materialized(
 select gr.id,gr.expires_at,gr.available_at,gr.created_at,coalesce(sum(p.amount_minor),0)::bigint book
 from public.boss_bucks_grants gr join public.boss_bucks_journals jj on jj.grant_id=gr.id
 join public.boss_bucks_postings p on p.journal_id=jj.id and p.account_id=gr.account_id
 where gr.wallet_id=w.id and gr.organization_id=org and gr.available_at<=clock_timestamp()and(gr.expires_at is null or gr.expires_at>clock_timestamp())
 group by gr.id having sum(p.amount_minor)>0)
 select *from balances order by expires_at nulls last,available_at,created_at,id limit 200 loop
 perform 1 from public.boss_bucks_grants where id=g.id for update;
 if g.expires_at<=clock_timestamp()then continue;end if;
 take:=least(g.book,remaining);j:=boss_private.bucks_pair(g.id,'spend',take,'Canonical charge payment');ordinal:=ordinal+1;
 while take>0 loop
 chunk:=least(take,allocation_left[allocation_index]);
 insert into public.boss_bucks_consumptions(allocation_id,grant_id,journal_id,amount_minor,ordinal)values(allocation_ids[allocation_index],g.id,j,chunk,ordinal);
 take:=take-chunk;allocation_left[allocation_index]:=allocation_left[allocation_index]-chunk;
 if allocation_left[allocation_index]=0 then allocation_index:=allocation_index+1;end if;end loop;
 remaining:=remaining-(select amount_minor from public.boss_bucks_journals where id=j);exit when remaining=0;end loop;
 if remaining<>0 then raise exception'Grant selection changed or bounded batch exceeded'using errcode='PT409';end if;
 select jsonb_build_object('payment_id',payment,'organization',(select name from public.organizations where id=org),'organization_id',org,
 'method','boss_bucks','currency',w.currency,'amount_minor',amount,'at',(select received_at from public.payments where id=payment),'checkout_id',coalesce((i->>'checkout_id')::uuid,request),
 'charges',jsonb_agg(jsonb_build_object('charge_id',ch.id,'title',ch.title,'amount_minor',a.amount_minor,'remaining_minor',(boss_private.registration_charge_balance(ch.id)->>'balance_due_minor')::bigint)order by ch.id))into receipt
 from public.payment_allocations a join public.charges ch on ch.id=a.charge_id where a.payment_id=payment;
 result:=boss_private.bucks_safe_money_json(jsonb_build_object('action','payment.spend','replayed',false,'receipt',receipt));
 perform boss_private.bucks_audit(actor,'boss_bucks.payment.spend',org,w.id,null,request,jsonb_build_object('payment_id',payment,'amount_minor',amount,'allocation_count',cardinality(allocation_ids),'grant_count',ordinal));
 insert into boss_private.bucks_requests(request_id,actor_id,command,result)values(request,actor,command,result);return result;
end$$;

alter function boss_private.bucks_mutate(jsonb)rename to bucks_mutate_phase7b;
create function boss_private.bucks_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare actor uuid;begin
 if command->>'action'not in('payment.spend','payment.reverse')then return boss_private.bucks_mutate_phase7b(command);end if;
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 if actor is null then raise exception'Authentication required'using errcode='PT401';end if;
 if jsonb_typeof(command)is distinct from'object'or exists(select 1 from jsonb_object_keys(command)k where k<>all(array['action','input','request_id']))
 or(command->>'request_id')::uuid is null then raise exception'Invalid payment command'using errcode='PT422';end if;
 if command->>'action'='payment.spend'then return boss_private.bucks_spend(actor,command);end if;
 -- The reversal implementation follows the source/recovery decision.
 raise exception'Payment reversal not yet installed'using errcode='PT409';
exception when invalid_text_representation or numeric_value_out_of_range then raise exception'Invalid payment fields'using errcode='PT422';end$$;
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
grant execute on function boss_private.bucks_read(jsonb),boss_private.bucks_mutate(jsonb),boss_private.bucks_admin_feature(uuid,text)to authenticated;
