-- Binding Main Boss Chat rule: return covered recovery through its actual
-- replacement-grant lineage, most recent satisfaction first. Invalid/expired
-- replacement value cannot become spendable; dependent claims unwind as well.
create function boss_private.bucks_cancel_recovery(grant_uuid uuid,amount bigint,reversal_uuid uuid,cause_release uuid default null,depth integer default 0)
returns uuid language plpgsql volatile security definer set search_path=''as $$
declare g public.boss_bucks_grants;replacement public.boss_bucks_grants;claim uuid;outstanding bigint;remaining bigint;take bigint;invalid_take bigint;
 applied record;j uuid;invalid_j uuid;cancel_j uuid;release_uuid uuid;begin
 if depth>64 or amount is null or amount<=0 then raise exception'Recovery unwind bound exceeded'using errcode='PT409';end if;
 select *into g from public.boss_bucks_grants where id=grant_uuid for update;
 select id into claim from public.boss_bucks_recovery_claims where grant_id=g.id;
 if claim is null then raise exception'Recovery lineage missing'using errcode='PT409';end if;
 outstanding:=boss_private.bucks_claim_balance(claim);remaining:=greatest(amount-outstanding,0);
 if cause_release is not null then invalid_j:=boss_private.bucks_pair(g.id,'reversal',amount,'Invalid replacement recovery release remains unavailable');end if;
 cancel_j:=boss_private.bucks_pair(g.id,case when cause_release is null then'recovery_cancel'else'recovery_cancel_source'end,amount,'Payment return reduces internal recovery exposure');
 insert into public.boss_bucks_recovery_movements(claim_id,kind,amount_minor,journal_id,payment_reversal_id,cause_release_id,invalid_release_journal_id)
 values(claim,'cancel',amount,cancel_j,reversal_uuid,cause_release,invalid_j);
 for applied in select m.*,m.amount_minor-coalesce((select sum(r.amount_minor)from public.boss_bucks_recovery_movements r where r.original_movement_id=m.id),0)unreleased
 from public.boss_bucks_recovery_movements m where m.claim_id=claim and m.kind='apply'order by m.created_at desc,m.id desc loop
 exit when remaining=0;if applied.unreleased=0 then continue;end if;
 if(select count(*)from public.boss_bucks_recovery_movements where payment_reversal_id=reversal_uuid)>1000 then raise exception'Recovery unwind batch exceeded'using errcode='PT409';end if;
 take:=least(remaining,applied.unreleased);
 select *into replacement from public.boss_bucks_grants where id=applied.replacement_grant_id for update;
 if replacement.wallet_id<>g.wallet_id or replacement.organization_id<>g.organization_id or replacement.currency<>g.currency then raise exception'Recovery scope mismatch'using errcode='PT409';end if;
 invalid_take:=least(take,greatest(boss_private.bucks_net_use(replacement.id)-boss_private.bucks_entitlement(replacement.id),0));
 j:=boss_private.bucks_pair(replacement.id,'recovery_release',take,'Original payment return unwinds recorded recovery satisfaction');
 insert into public.boss_bucks_recovery_movements(claim_id,kind,amount_minor,replacement_grant_id,journal_id,payment_reversal_id,original_movement_id)
 values(claim,'release',take,replacement.id,j,reversal_uuid,applied.id)returning id into release_uuid;
 perform boss_private.bucks_audit(null,'boss_bucks.recovery.release',g.organization_id,g.wallet_id,replacement.id,null,
 jsonb_build_object('movement_id',release_uuid,'original_movement_id',applied.id,'claim_id',claim,'payment_reversal_id',reversal_uuid,'amount_minor',take));
 if invalid_take>0 then perform boss_private.bucks_cancel_recovery(replacement.id,invalid_take,reversal_uuid,release_uuid,depth+1);end if;
 if replacement.expires_at<=clock_timestamp()then perform boss_private.bucks_post(replacement.id,'expiration','Replacement original expiration retained on recovery release');end if;
 remaining:=remaining-take;end loop;
 if remaining<>0 then raise exception'Recovery satisfaction lineage incomplete'using errcode='PT409';end if;
 perform boss_private.bucks_audit(null,'boss_bucks.recovery.cancel',g.organization_id,g.wallet_id,g.id,null,
 jsonb_build_object('journal_id',cancel_j,'claim_id',claim,'payment_reversal_id',reversal_uuid,'cause_release_id',cause_release,'amount_minor',amount));
 return cancel_j;
end$$;
create function boss_private.bucks_reverse(actor uuid,command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb:=command->'input';request uuid:=(command->>'request_id')::uuid;p public.payments;t public.boss_bucks_tenders;w public.boss_bucks_wallets;
 original_allocation public.payment_allocations;x jsonb;total bigint:=0;reversal uuid:=gen_random_uuid();reversed_allocation uuid;remaining bigint;take bigint;invalid_take bigint;valid_take bigint;
 consumed record;g public.boss_bucks_grants;claim uuid;outstanding bigint;j uuid;result jsonb;prior boss_private.bucks_requests;begin
 if jsonb_typeof(i)is distinct from'object'or exists(select 1 from jsonb_object_keys(i)k where k<>all(array['payment_id','allocations','reason']))
 or not(i?&array['payment_id','allocations','reason'])or jsonb_typeof(i->'allocations')is distinct from'array'
 or jsonb_array_length(i->'allocations')not between 1 and 50 or jsonb_typeof(i->'reason')is distinct from'string'or length(btrim(i->>'reason'))not between 1 and 200 then raise exception'Invalid reversal fields'using errcode='PT422';end if;
 select *into p from public.payments where id=(i->>'payment_id')::uuid;
 select *into t from public.boss_bucks_tenders where payment_id=p.id;select *into w from public.boss_bucks_wallets where id=t.wallet_id;
 if p.id is null or p.method<>'boss_bucks'or p.status<>'recorded'or t.payment_id is null then raise exception'Access denied'using errcode='PT403';end if;
 if not boss_private.bucks_role(actor,'boss_bucks.payment_reverse',p.organization_id)or not boss_private.bucks_feature(p.organization_id,'charge_payments')or not boss_private.registration_feature(p.organization_id,'fees')then raise exception'Access denied'using errcode='PT403';end if;
 perform boss_private.bucks_payment_fence(actor,p.organization_id,w.id,w.household_id);
 for x in select value from jsonb_array_elements(i->'allocations')loop
 if jsonb_typeof(x)is distinct from'object'or exists(select 1 from jsonb_object_keys(x)k where k<>all(array['allocation_id','amount_minor']))
 or not(x?&array['allocation_id','amount_minor'])or coalesce(x->>'amount_minor','')!~'^[1-9][0-9]{0,9}$'or(x->>'amount_minor')::bigint>1000000000 then raise exception'Invalid reversal allocation'using errcode='PT422';end if;
 total:=total+(x->>'amount_minor')::bigint;end loop;
 if total>1000000000 or(select count(distinct(value->>'allocation_id')::uuid)from jsonb_array_elements(i->'allocations'))<>jsonb_array_length(i->'allocations')then raise exception'Invalid reversal allocation list'using errcode='PT422';end if;
 for original_allocation in select a.*from public.payment_allocations a where a.id in(select(value->>'allocation_id')::uuid from jsonb_array_elements(i->'allocations'))order by a.charge_id,a.id loop
 if original_allocation.payment_id<>p.id or original_allocation.status<>'applied'then raise exception'Access denied'using errcode='PT403';end if;
 perform 1 from public.charges where id=original_allocation.charge_id for update;
 update public.charges set status=status where id=original_allocation.charge_id;end loop;
 if(select count(*)from public.payment_allocations a where a.payment_id=p.id and a.status='applied'and a.id in(select(value->>'allocation_id')::uuid from jsonb_array_elements(i->'allocations')))<>jsonb_array_length(i->'allocations')then raise exception'Access denied'using errcode='PT403';end if;
 perform boss_private.bucks_wallet_lock(w.id);
 perform 1 from public.boss_bucks_accounts where wallet_id=w.id and organization_id=p.organization_id order by id for update;
 perform 1 from public.payments where id=p.id for update;
 perform 1 from public.payment_allocations where payment_id=p.id order by id for update;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.current_person_id()or not boss_private.bucks_role(actor,'boss_bucks.payment_reverse',p.organization_id)
 or not boss_private.bucks_feature(p.organization_id,'charge_payments')or not boss_private.registration_feature(p.organization_id,'fees')
 or not exists(select 1 from public.organization_modules m join public.modules k on k.id=m.module_id and k.key='registration'and k.status='active'
 where m.organization_id=p.organization_id and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))then raise exception'Access denied'using errcode='PT403';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-bucks-request:'||request::text,0));
 select *into prior from boss_private.bucks_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command<>command then raise exception'Request conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true}'::jsonb;end if;
 if total>p.amount_minor-(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=p.id)then raise exception'Payment reversal exceeds remaining amount'using errcode='PT409';end if;
 for x in select value from jsonb_array_elements(i->'allocations')loop
 select *into original_allocation from public.payment_allocations where id=(x->>'allocation_id')::uuid;
 if(x->>'amount_minor')::bigint>original_allocation.amount_minor-(select coalesce(sum(amount_minor),0)from public.payment_allocations where reversal_of_id=original_allocation.id)then raise exception'Allocation reversal exceeds remaining amount'using errcode='PT409';end if;end loop;
 insert into public.payments(id,organization_id,method,amount_minor,currency,payer_person_id,received_at,reference,note,source_reference,recorded_by_person_id,status,reversal_of_id)
 values(reversal,p.organization_id,'boss_bucks',total,p.currency,p.payer_person_id,clock_timestamp(),request::text,i->>'reason',request::text,actor,'reversed',p.id);
 insert into public.boss_bucks_tenders(payment_id,wallet_id,organization_id,currency,actor_person_id,request_id,checkout_id,original_payment_id)
 values(reversal,w.id,p.organization_id,p.currency,actor,request,t.checkout_id,p.id);
 for x in select value from jsonb_array_elements(i->'allocations')order by (value->>'allocation_id')::uuid loop
 select *into original_allocation from public.payment_allocations where id=(x->>'allocation_id')::uuid;remaining:=(x->>'amount_minor')::bigint;
 insert into public.payment_allocations(organization_id,payment_id,charge_id,amount_minor,status,reversal_of_id)
 values(p.organization_id,reversal,original_allocation.charge_id,remaining,'reversed',original_allocation.id)returning id into reversed_allocation;
 for consumed in select bc.*,bc.amount_minor-coalesce((select sum(br.amount_minor)from public.boss_bucks_restorations br where br.consumption_id=bc.id),0)unrestored
 from public.boss_bucks_consumptions bc where bc.allocation_id=original_allocation.id order by bc.ordinal,bc.id loop
 exit when remaining=0;if consumed.unrestored=0 then continue;end if;take:=least(remaining,consumed.unrestored);
 select *into g from public.boss_bucks_grants where id=consumed.grant_id for update;
 invalid_take:=least(take,greatest(boss_private.bucks_net_use(g.id)-boss_private.bucks_entitlement(g.id),0));valid_take:=take-invalid_take;
 if invalid_take>0 then
 j:=boss_private.bucks_cancel_recovery(g.id,invalid_take,reversal);
 insert into public.boss_bucks_restorations(consumption_id,allocation_id,journal_id,amount_minor)values(consumed.id,reversed_allocation,j,invalid_take);
 end if;
 if valid_take>0 then
 j:=boss_private.bucks_pair(g.id,'payment_restore',valid_take,'Canonical payment reversal to original earning source');
 insert into public.boss_bucks_restorations(consumption_id,allocation_id,journal_id,amount_minor)values(consumed.id,reversed_allocation,j,valid_take);
 if g.expires_at<=clock_timestamp()then perform boss_private.bucks_post(g.id,'expiration','Original earning expiration retained on payment return');end if;end if;
 remaining:=remaining-take;end loop;
 if remaining<>0 then raise exception'Original consumption changed'using errcode='PT409';end if;end loop;
 result:=boss_private.bucks_safe_money_json(jsonb_build_object('action','payment.reverse','replayed',false,'receipt',boss_private.bucks_receipt(reversal)));
 perform boss_private.bucks_audit(actor,'boss_bucks.payment.reverse',p.organization_id,w.id,null,request,jsonb_build_object('payment_id',reversal,'original_payment_id',p.id,'amount_minor',total,'reason',i->>'reason'));
 insert into boss_private.bucks_requests(request_id,actor_id,command,result)values(request,actor,command,result);return result;
end$$;
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.bucks_mutate(jsonb)'::regprocedure);
 if position('raise exception''Payment reversal not yet installed'''in d)=0 then raise exception'Reversal dispatcher checkpoint mismatch';end if;
 d:=replace(d,'raise exception''Payment reversal not yet installed''using errcode=''PT409'';','return boss_private.bucks_reverse(actor,command);');execute d;
end$$;
revoke all on function boss_private.bucks_reverse(uuid,jsonb)from public,anon,authenticated,service_role;
revoke all on function boss_private.bucks_cancel_recovery(uuid,bigint,uuid,uuid,integer)from public,anon,authenticated,service_role;
