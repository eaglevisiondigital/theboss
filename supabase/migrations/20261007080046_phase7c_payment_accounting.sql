create function boss_private.bucks_grant_book(grant_uuid uuid)returns bigint language sql volatile security definer set search_path=''as $$
 -- Parameterize each posting sum by its journal's unique account pair. A
 -- common household account must not turn every grant check into a full
 -- household-posting scan during large deferred batches.
 select coalesce(sum(posting.total),0)::bigint from public.boss_bucks_grants g join public.boss_bucks_journals j on j.grant_id=g.id
 cross join lateral(select sum(p.amount_minor)total from public.boss_bucks_postings p where p.journal_id=j.id and p.account_id=g.account_id)posting
 where g.id=grant_uuid
$$;
create function boss_private.bucks_entitlement(grant_uuid uuid)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce((select entitlement_minor from public.boss_bucks_source_corrections where grant_id=g.id order by created_at desc,id desc limit 1),
 case when exists(select 1 from public.boss_bucks_journals where grant_id=g.id and kind='reversal'and amount_minor is null)then 0 else g.amount_minor end)
 from public.boss_bucks_grants g where g.id=grant_uuid
$$;
create function boss_private.bucks_claim_balance(claim uuid)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce(sum(case kind when'open'then amount_minor when'release'then amount_minor else -amount_minor end),0)::bigint
 from public.boss_bucks_recovery_movements where claim_id=claim
$$;
create function boss_private.bucks_recovery_due(wallet uuid,org uuid)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce(sum(boss_private.bucks_claim_balance(c.id)),0)::bigint from public.boss_bucks_recovery_claims c
 join public.boss_bucks_grants g on g.id=c.grant_id where g.wallet_id=wallet and g.organization_id=org
$$;
-- A real write fence protects the immutable ledger against stale snapshots.
-- No posted/available balance cache is authoritative.
create function boss_private.bucks_wallet_lock(wallet uuid)returns void language plpgsql volatile security definer set search_path=''as $$begin
 perform 1 from public.boss_bucks_wallets where id=wallet for update;
 update public.boss_bucks_wallets set status=status where id=wallet;
end$$;
create function boss_private.bucks_pair(grant_uuid uuid,p_kind text,p_amount bigint,p_reason text)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare g public.boss_bucks_grants;original uuid;j uuid;left_kind text;right_kind text;left_id uuid;right_id uuid;sign integer;begin
 select *into g from public.boss_bucks_grants where id=grant_uuid;
 if g.id is null or p_amount is null or p_amount not between 1 and g.amount_minor then raise exception'Invalid grant amount'using errcode='PT422';end if;
 left_kind:=case when p_kind in('recovery_open','recovery_cancel','recovery_cancel_source')then'recovery'else'household'end;
 right_kind:=case when p_kind in('spend','payment_restore','recovery_cancel')then'redemption'when p_kind in('recovery_apply','recovery_release')then'recovery'else'clearing'end;
 sign:=case when p_kind in('issuance','payment_restore','recovery_cancel','recovery_cancel_source','recovery_release')then 1 else -1 end;
 if p_kind not in('issuance','reversal','expiration','spend','payment_restore','recovery_open','recovery_apply','recovery_cancel','recovery_cancel_source','recovery_release')then raise exception'Invalid journal kind'using errcode='PT422';end if;
 if p_kind<>'issuance'then select id into original from public.boss_bucks_journals where grant_id=g.id and kind='issuance';end if;
 if left_kind='household'then left_id:=g.account_id;else
 insert into public.boss_bucks_accounts(kind,wallet_id,household_id,organization_id,currency)values('recovery',g.wallet_id,g.household_id,g.organization_id,g.currency)
 on conflict(wallet_id,organization_id,currency)where kind='recovery'do nothing;
 select id into left_id from public.boss_bucks_accounts where kind='recovery'and wallet_id=g.wallet_id and organization_id=g.organization_id and currency=g.currency;end if;
 if right_kind='recovery'then
 insert into public.boss_bucks_accounts(kind,wallet_id,household_id,organization_id,currency)values('recovery',g.wallet_id,g.household_id,g.organization_id,g.currency)
 on conflict(wallet_id,organization_id,currency)where kind='recovery'do nothing;
 select id into right_id from public.boss_bucks_accounts where kind='recovery'and wallet_id=g.wallet_id and organization_id=g.organization_id and currency=g.currency;
 else
 insert into public.boss_bucks_accounts(kind,organization_id,currency)values(right_kind,g.organization_id,g.currency)on conflict do nothing;
 select id into right_id from public.boss_bucks_accounts where kind=right_kind and organization_id=g.organization_id and currency=g.currency;end if;
 insert into public.boss_bucks_journals(grant_id,kind,currency,original_journal_id,reason,amount_minor)values(g.id,p_kind,g.currency,original,p_reason,p_amount)returning id into j;
 insert into public.boss_bucks_postings(journal_id,account_id,currency,amount_minor)values(j,left_id,g.currency,sign*p_amount),(j,right_id,g.currency,-sign*p_amount);
 return j;
end$$;

create or replace function boss_private.bucks_validate_journal()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare j public.boss_bucks_journals;g public.boss_bucks_grants;original public.boss_bucks_journals;n integer;total numeric;amount bigint;left_kind text;right_kind text;sign integer;book bigint;begin
 select *into j from public.boss_bucks_journals where id=coalesce((to_jsonb(new)->>'journal_id')::uuid,new.id);
 select *into g from public.boss_bucks_grants where id=j.grant_id;amount:=coalesce(j.amount_minor,g.amount_minor);
 left_kind:=case when j.kind in('recovery_open','recovery_cancel','recovery_cancel_source')then'recovery'else'household'end;
 right_kind:=case when j.kind in('spend','payment_restore','recovery_cancel')then'redemption'when j.kind in('recovery_apply','recovery_release')then'recovery'else'clearing'end;
 sign:=case when j.kind in('issuance','payment_restore','recovery_cancel','recovery_cancel_source','recovery_release')then 1 else -1 end;
 select count(*),sum(p.amount_minor)into n,total from public.boss_bucks_postings p where journal_id=j.id;
 if n<>2 or total<>0 or j.currency<>g.currency or amount>g.amount_minor or j.kind='issuance'and amount<>g.amount_minor
 or exists(select 1 from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where p.journal_id=j.id and(
 p.currency<>j.currency or a.currency<>j.currency or a.organization_id<>g.organization_id
 or a.kind not in(left_kind,right_kind)
 or a.kind in('household','recovery')and(a.wallet_id<>g.wallet_id or a.household_id<>g.household_id)
 or a.kind='household'and a.id<>g.account_id
 or p.amount_minor<>(case when a.kind=left_kind then sign else -sign end)*amount))
 or(select count(*)from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where p.journal_id=j.id and a.kind=left_kind)<>1 then
 raise exception'Invalid balanced wallet journal'using errcode='23514';end if;
 if j.kind<>'issuance'then
 select *into original from public.boss_bucks_journals where id=j.original_journal_id;
 if original.grant_id<>j.grant_id or original.kind<>'issuance'or original.currency<>j.currency or original.created_at>j.created_at then raise exception'Invalid dependent journal'using errcode='23514';end if;
 if j.kind='expiration'and(g.expires_at is null or g.expires_at>j.created_at)then raise exception'Premature expiration'using errcode='23514';end if;end if;
 if j.kind='spend'and(g.available_at>j.created_at or g.expires_at<=j.created_at)then raise exception'Spend source unavailable at commitment'using errcode='23514';end if;
 if j.kind='spend'and(select coalesce(sum(c.amount_minor),0)from public.boss_bucks_consumptions c where c.journal_id=j.id)<>amount
 or j.kind='payment_restore'and(select coalesce(sum(r.amount_minor),0)from public.boss_bucks_restorations r where r.journal_id=j.id)<>amount
 or j.kind in('recovery_open','recovery_apply','recovery_cancel','recovery_cancel_source','recovery_release')and not exists(select 1 from public.boss_bucks_recovery_movements m where m.journal_id=j.id and m.amount_minor=amount)then
 raise exception'Journal requires dependency evidence'using errcode='23514';end if;
 book:=boss_private.bucks_grant_book(g.id);
 if book<0 or book>g.amount_minor then raise exception'Grant balance exceeded'using errcode='23514';end if;
 return new;
end$$;

create function boss_private.bucks_validate_payment()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare p public.payments;t public.boss_bucks_tenders;a record;w public.boss_bucks_wallets;original public.payments;begin
 select *into p from public.payments where id=case when tg_table_name='payments'then (to_jsonb(new)->>'id')::uuid else (to_jsonb(new)->>'payment_id')::uuid end;
 if p.method<>'boss_bucks'then return new;end if;
 select *into t from public.boss_bucks_tenders where payment_id=p.id;select *into w from public.boss_bucks_wallets where id=t.wallet_id;
 if t.payment_id is null or t.organization_id<>p.organization_id or t.currency<>p.currency or w.currency<>p.currency
 or t.actor_person_id<>p.recorded_by_person_id or(t.original_payment_id is null)<>(p.status='recorded')
 or t.original_payment_id is distinct from p.reversal_of_id
 or(select coalesce(sum(amount_minor),0)from public.payment_allocations where payment_id=p.id)<>p.amount_minor
 or(select count(distinct charge_id)from public.payment_allocations where payment_id=p.id)<>(select count(*)from public.payment_allocations where payment_id=p.id)then raise exception'Internal payment lacks canonical wallet evidence'using errcode='23514';end if;
 if p.status='reversed'then
 select *into original from public.payments where id=p.reversal_of_id;
 if original.method<>'boss_bucks'or original.status<>'recorded'or original.currency<>p.currency or original.payer_person_id<>p.payer_person_id
 or(select wallet_id from public.boss_bucks_tenders where payment_id=original.id)<>t.wallet_id
 or(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=original.id)>original.amount_minor then raise exception'Invalid internal payment reversal'using errcode='23514';end if;end if;
 for a in select pa.*,c.household_id,c.currency charge_currency,c.organization_id charge_org from public.payment_allocations pa join public.charges c on c.id=pa.charge_id where pa.payment_id=p.id loop
 if a.household_id is distinct from w.household_id or a.charge_currency<>p.currency or a.charge_org<>p.organization_id
 or(a.status='applied')<>(p.status='recorded')then raise exception'Allocation context mismatch'using errcode='23514';end if;
 if(boss_private.registration_charge_balance(a.charge_id)->>'applied_amount_minor')::bigint>(boss_private.registration_charge_balance(a.charge_id)->>'adjusted_amount_minor')::bigint then raise exception'Charge allocation exceeds current obligation'using errcode='23514';end if;
 if p.status='recorded'and(select coalesce(sum(amount_minor),0)from public.boss_bucks_consumptions where allocation_id=a.id)<>a.amount_minor
 or p.status='reversed'and(select coalesce(sum(amount_minor),0)from public.boss_bucks_restorations where allocation_id=a.id)<>a.amount_minor then raise exception'Allocation lacks grant lineage'using errcode='23514';end if;
 if p.status='reversed'and not exists(select 1 from public.payment_allocations oa where oa.id=a.reversal_of_id and oa.payment_id=p.reversal_of_id and oa.charge_id=a.charge_id and oa.status='applied'
 and oa.amount_minor>=(select sum(amount_minor)from public.payment_allocations where reversal_of_id=oa.id))then raise exception'Allocation reversal exceeded'using errcode='23514';end if;
 end loop;return new;
end$$;
create constraint trigger boss_bucks_payment_proof after insert on public.payments deferrable initially deferred for each row execute function boss_private.bucks_validate_payment();
create constraint trigger boss_bucks_allocation_proof after insert on public.payment_allocations deferrable initially deferred for each row execute function boss_private.bucks_validate_payment();
create constraint trigger boss_bucks_tender_proof after insert on public.boss_bucks_tenders deferrable initially deferred for each row execute function boss_private.bucks_validate_payment();

create function boss_private.bucks_validate_consumption()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare c public.boss_bucks_consumptions;j public.boss_bucks_journals;g public.boss_bucks_grants;a public.payment_allocations;t public.boss_bucks_tenders;begin
 select *into c from public.boss_bucks_consumptions where id=case when tg_table_name='boss_bucks_restorations'then (to_jsonb(new)->>'consumption_id')::uuid else (to_jsonb(new)->>'id')::uuid end;
 select *into j from public.boss_bucks_journals where id=c.journal_id;select *into g from public.boss_bucks_grants where id=c.grant_id;
 select *into a from public.payment_allocations where id=c.allocation_id;select *into t from public.boss_bucks_tenders where payment_id=a.payment_id;
 if j.kind<>'spend'or j.grant_id<>g.id or a.status<>'applied'or a.organization_id<>g.organization_id or t.wallet_id<>g.wallet_id or t.currency<>g.currency
 or(select coalesce(sum(amount_minor),0)from public.boss_bucks_restorations where consumption_id=c.id)>c.amount_minor then raise exception'Invalid grant consumption'using errcode='23514';end if;
 if tg_table_name='boss_bucks_restorations'and not exists(select 1 from public.payment_allocations r join public.boss_bucks_journals rj on rj.id=new.journal_id
 where r.id=new.allocation_id and r.status='reversed'and r.reversal_of_id=c.allocation_id and rj.grant_id=c.grant_id and rj.kind in('payment_restore','recovery_cancel')and rj.amount_minor=new.amount_minor)then raise exception'Invalid grant restoration'using errcode='23514';end if;
 return new;
end$$;
create constraint trigger boss_bucks_consumption_proof after insert on public.boss_bucks_consumptions deferrable initially deferred for each row execute function boss_private.bucks_validate_consumption();
create constraint trigger boss_bucks_restoration_proof after insert on public.boss_bucks_restorations deferrable initially deferred for each row execute function boss_private.bucks_validate_consumption();

do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
grant execute on function boss_private.bucks_read(jsonb),boss_private.bucks_mutate(jsonb),boss_private.bucks_admin_feature(uuid,text)to authenticated;
