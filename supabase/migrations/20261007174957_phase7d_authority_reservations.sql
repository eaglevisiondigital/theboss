create function boss_private.rails_feature(org uuid,feature text) returns boolean language sql volatile security definer set search_path='' as $$
 select feature in('online_payments','provider_configuration','settlement','refunds','reconciliation','public_fundraising','saved_methods','recurring_execution') and exists(
 select 1 from public.organization_modules m join public.modules k on k.id=m.module_id and k.key='payments' and k.status='active'
 join public.organizations o on o.id=m.organization_id and o.status='active'
 where m.organization_id=org and m.status='active' and m.starts_at<=clock_timestamp() and(m.ends_at is null or m.ends_at>clock_timestamp())
 and m.configuration->feature='true'::jsonb)
$$;
create function boss_private.rails_role(actor uuid,permission text,org uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select permission in('payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile')
 and exists(select 1 from public.people where id=actor and status='active')
 and exists(select 1 from public.organizations where id=org and status='active') and exists(
 select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.key=permission and p.status='active'
 where a.person_id=actor and a.status='active' and a.starts_at<=clock_timestamp() and(a.ends_at is null or a.ends_at>clock_timestamp()) and(
 a.scope_type='platform' and a.scope_id is null and a.organization_id is null and r.key in('super_administrator','platform_administrator')
 or a.scope_type='organization' and a.organization_id=org and a.scope_id=org and exists(
 select 1 from public.organization_memberships m where m.person_id=actor and m.organization_id=org and m.status='active'
 and m.starts_at<=clock_timestamp() and(m.ends_at is null or m.ends_at>clock_timestamp()))))
$$;
create function boss_private.rails_amount(i jsonb,k text,zero_allowed boolean default false) returns bigint language plpgsql immutable set search_path='' as $$
 declare n bigint;begin
 if jsonb_typeof(i->k) not in('number','string') or coalesce(i->>k,'')!~'^(0|[1-9][0-9]{0,9})$' then raise exception'Invalid payment amount' using errcode='PT422';end if;
 n:=(i->>k)::bigint;if n>1000000000 or n=0 and not zero_allowed then raise exception'Invalid payment amount' using errcode='PT422';end if;return n;
 end$$;
create function boss_private.rails_actor_current(actor uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.people p join public.user_accounts a on a.person_id=p.id join auth.users u on u.id=a.auth_user_id
 where p.id=actor and p.status='active' and a.account_status='active' and u.deleted_at is null and not u.is_anonymous
 and u.email_confirmed_at is not null and(u.banned_until is null or u.banned_until<=clock_timestamp()))
$$;
create function boss_private.rails_charge_authorized(actor uuid,charge uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.rails_actor_current(actor) and exists(
 select 1 from public.charges c join public.participants p on p.id=c.participant_id and p.status='active'
 join public.people child on child.id=p.person_id and child.status='active'
 where c.id=charge and c.status='active' and boss_private.registration_feature(c.organization_id,'fees')
 and boss_private.rails_feature(c.organization_id,'online_payments')
 and (p.person_id=actor or exists(select 1 from public.guardian_relationships g where g.guardian_person_id=actor and g.dependent_person_id=p.person_id
 and g.can_manage_payments and g.authority_status='active' and g.verified_at<=clock_timestamp() and g.starts_at<=clock_timestamp()
 and(g.ends_at is null or g.ends_at>clock_timestamp()))))
$$;
create function boss_private.rails_audit(actor uuid,org uuid,action text,resource uuid,request uuid default null,details jsonb default '{}') returns void language plpgsql volatile security definer set search_path='' as $$begin
 insert into public.payment_history(organization_id,actor_id,action,resource_id,request_id,details) values(org,actor,action,resource,request,details);
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(org,actor,case when actor is not null then auth.uid() end,action,'payment',resource,'organization',org,request,details);
end$$;
create function boss_private.rails_fence(actor uuid,org uuid,wallet uuid default null) returns void language plpgsql volatile security definer set search_path='' as $$declare household uuid;begin
 perform 1 from public.organization_modules where organization_id=org and module_id in(select id from public.modules where key in('payments','boss_bucks','registration','fundraising','money_board')) order by id for share;
 select household_id into household from public.boss_bucks_wallets where id=wallet;
 perform boss_private.bucks_payment_fence(actor,org,null,household);
 perform 1 from auth.users where id in(select auth_user_id from public.user_accounts where person_id=actor) for share;
end$$;
create function boss_private.rails_account_ready(account uuid,org uuid,method text,currency text) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.processing_accounts a join boss_private.processing_bindings b on b.account_id=a.id
 where a.id=account and a.organization_id=org and a.status='active' and b.revoked_at is null
 and b.verified_environment=a.environment and b.verified_merchant_reference=a.merchant_reference
 and currency=any(a.currencies) and case method when 'card' then 'card_sale'=any(a.capabilities) when 'ach' then 'ach'=any(a.capabilities) else false end)
$$;
create function boss_private.rails_route_current(route uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.payment_routing_revisions r where r.id=route and r.starts_at<=clock_timestamp() and(r.ends_at is null or r.ends_at>clock_timestamp())
 and r.revision=(select max(n.revision) from public.payment_routing_revisions n where n.organization_id=r.organization_id and n.purpose=r.purpose and n.currency=r.currency and n.scope_type=r.scope_type and n.scope_id=r.scope_id)
 and (select e.state from public.payment_routing_events e where e.routing_id=r.id order by e.created_at desc,e.id desc limit 1)='active')
$$;
create function boss_private.rails_route_charge(route uuid,charge uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.payment_routing_revisions r join public.charges c on c.organization_id=r.organization_id and c.currency=r.currency
 join public.registrations reg on reg.id=c.registration_id join public.registration_offerings o on o.id=reg.offering_id
 where r.id=route and c.id=charge and r.purpose='fees' and boss_private.rails_route_current(r.id) and(
 r.scope_type='organization' and r.scope_id=c.organization_id
 or r.scope_type='team' and (reg.assigned_team_id=r.scope_id or o.scope_type='team' and o.scope_id=r.scope_id)
 or r.scope_type='unit' and o.scope_type='unit' and o.scope_id=r.scope_id))
$$;
create function boss_private.rails_route_intent(route uuid,intent uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.payment_routing_revisions r join public.fundraising_campaigns c on c.organization_id=r.organization_id
 join public.fundraising_intents i on i.campaign_id=c.id and i.currency=r.currency left join public.fundraising_fundraisers f on f.id=i.fundraiser_id
 where r.id=route and i.id=intent and r.purpose='fundraising' and boss_private.rails_route_current(r.id) and(
 r.scope_type='organization' and r.scope_id=c.organization_id or r.scope_type='campaign' and r.scope_id=c.id
 or r.scope_type='team' and r.scope_id=f.team_id or r.scope_type='unit' and r.scope_id=f.unit_id))
$$;

-- Reservations are not journals. Availability and FEFO execution both subtract
-- live reserved slices, preventing another committed spend consuming held lots.
create function boss_private.rails_grant_reserved(grant_uuid uuid) returns bigint language sql volatile security definer set search_path='' as $$
 select coalesce(sum(r.amount_minor),0)::bigint from public.boss_bucks_checkout_reservations r join public.payment_checkouts c on c.id=r.checkout_id
 where r.grant_id=grant_uuid and c.state in('ready','external_pending','unknown','authorized','ach_pending') and c.expires_at>clock_timestamp()
$$;
create or replace function boss_private.bucks_available(wallet uuid,org uuid default null) returns bigint language sql volatile security definer set search_path='' as $$
 select coalesce(sum(greatest(0,boss_private.bucks_grant_book(g.id)-boss_private.rails_grant_reserved(g.id))),0)::bigint
 from public.boss_bucks_grants g join public.organizations o on o.id=g.organization_id and o.status='active'
 where g.wallet_id=wallet and(org is null or g.organization_id=org) and g.available_at<=clock_timestamp() and(g.expires_at is null or g.expires_at>clock_timestamp())
$$;
-- The explicit actor guard is equivalent to the signed Phase 7C guardian guard,
-- without a redundant current-JWT lookup. Its signed entry point still verifies
-- the caller and live session; private async completion never impersonates one.
create or replace function boss_private.bucks_payment_guardian(actor uuid,participant uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.participants p join public.people child on child.id=p.person_id and child.status='active'
 join public.guardian_relationships g on g.dependent_person_id=p.person_id and g.guardian_person_id=actor
 where p.id=participant and p.status='active' and g.can_manage_payments and g.authority_status='active'
 and g.verified_at<=clock_timestamp() and g.starts_at<=clock_timestamp() and(g.ends_at is null or g.ends_at>clock_timestamp()))
$$;
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.bucks_spend(uuid,jsonb)'::regprocedure);
 if position('coalesce(sum(p.amount_minor),0)::bigint book' in d)=0 or position('group by gr.id having sum(p.amount_minor)>0' in d)=0 then raise exception'Phase 7C spend checkpoint mismatch';end if;
 d:=replace(d,'coalesce(sum(p.amount_minor),0)::bigint book','greatest(0,coalesce(sum(p.amount_minor),0)::bigint-boss_private.rails_grant_reserved(gr.id)) book');
 d:=replace(d,'group by gr.id having sum(p.amount_minor)>0','group by gr.id having sum(p.amount_minor)>boss_private.rails_grant_reserved(gr.id)');execute d;
 -- Same financial implementation, separately closed async entry. Only the live
 -- signed transport checks change; current business authorization stays intact.
 d:=replace(d,'FUNCTION boss_private.bucks_spend(','FUNCTION boss_private.rails_bucks_commit(');
 d:=replace(d,'perform boss_private.games_require_live_auth();','if not boss_private.rails_actor_current(actor)then raise exception''Authentication required''using errcode=''PT401'';end if;');
 d:=replace(d,'if actor is distinct from boss_private.current_person_id()then','if not boss_private.rails_actor_current(actor)then');execute d;
end$$;

create function boss_private.rails_checkout_fence(checkout uuid) returns public.payment_checkouts language plpgsql volatile security definer set search_path='' as $$declare c public.payment_checkouts;a record;begin
 select *into c from public.payment_checkouts where id=checkout;if c.id is null then raise exception'Checkout unavailable' using errcode='PT404';end if;
 -- Preserve Phase 7A/B source hierarchy before obligation/wallet locks.
 if c.intent_id is not null then
 perform 1 from public.fundraising_campaigns where id=(select campaign_id from public.fundraising_intents where id=c.intent_id) for update;
 perform 1 from public.fundraising_fundraisers where id=(select fundraiser_id from public.fundraising_intents where id=c.intent_id) for update;
 end if;
 perform boss_private.rails_fence(c.actor_person_id,c.organization_id,c.wallet_id);
 perform 1 from public.processing_accounts where id=c.account_id for share;
 perform 1 from public.payment_routing_revisions where id=c.routing_id for share;
 for a in select charge_id from public.checkout_charge_allocations where checkout_id=c.id order by charge_id loop
 perform 1 from public.charges where id=a.charge_id for update;update public.charges set status=status where id=a.charge_id;end loop;
 if c.wallet_id is not null then perform boss_private.bucks_wallet_lock(c.wallet_id);end if;
 if c.intent_id is not null then perform 1 from public.fundraising_intents where id=c.intent_id for update;end if;
 select *into c from public.payment_checkouts where id=c.id for update;
 update public.payment_checkouts set state=state where id=c.id;
 return c;
end$$;
create function boss_private.rails_charge_reserved(charge uuid,except_checkout uuid default null) returns bigint language sql volatile security definer set search_path='' as $$
 select coalesce(sum(a.principal_minor),0)::bigint from public.checkout_charge_allocations a join public.payment_checkouts c on c.id=a.checkout_id
 where a.charge_id=charge and(c.id is distinct from except_checkout) and c.state in('ready','external_pending','unknown','authorized','ach_pending') and c.expires_at>clock_timestamp()
$$;
create function boss_private.rails_charge_unknown(charge uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.checkout_charge_allocations a join public.provider_operations o on o.checkout_id=a.checkout_id
 where a.charge_id=charge and o.kind in('sale','authorize','capture') and o.state in('dispatched','unknown','authorized','ach_pending'))
$$;
create function boss_private.rails_expire(batch integer default 100) returns integer language plpgsql volatile security definer set search_path='' as $$declare r record;c public.payment_checkouts;n integer:=0;begin
 if batch not between 1 and 100 then raise exception'Invalid expiry batch' using errcode='PT422';end if;
 for r in select id from public.payment_checkouts where state='ready' and expires_at<=clock_timestamp() order by expires_at,id limit batch loop
 c:=boss_private.rails_checkout_fence(r.id);if c.state<>'ready' or c.expires_at>clock_timestamp()then continue;end if;
 update public.payment_checkouts set state='expired' where id=c.id;
 insert into public.payment_checkout_events(checkout_id,kind)values(c.id,'expired');
 perform boss_private.rails_audit(null,c.organization_id,'payment.checkout.expired',c.id);n:=n+1;
 end loop;return n;
end$$;

-- Mutable workflow caches have immutable identity. History/evidence never rewrites.
-- External methods cannot appear through a fabricated canonical payment row.
-- No signed/operational commit entry exists at this local checkpoint. Refund
-- proof is deliberately denied until its reviewed reversal implementation exists.
create function boss_private.rails_external_payment_proof() returns trigger language plpgsql volatile security definer set search_path='' as $$declare p public.payments;begin
 select *into p from public.payments where id=new.id;
 if p.method not in('card','ach')then return null;end if;
 if not exists(select 1 from public.external_payment_tenders t
 join public.payment_checkouts c on c.id=t.checkout_id and c.organization_id=t.organization_id
 join public.provider_operations o on o.id=t.operation_id and o.checkout_id=c.id and o.account_id=c.account_id and o.organization_id=c.organization_id
 join public.provider_event_evidence e on e.id=t.event_id and e.account_id=c.account_id and e.operation_id=o.id
 where t.payment_id=p.id and t.organization_id=p.organization_id and t.original_payment_id is null
 and p.reversal_of_id is null and p.status='recorded' and o.kind in('sale','capture')and o.state='succeeded'
 and e.transaction_reference=o.provider_transaction_reference and e.amount_minor=p.amount_minor and p.amount_minor=c.external_minor
 and e.currency=p.currency and p.currency=c.currency and p.method=c.method
 and(p.method='card'and e.kind in('captured','settled')or p.method='ach'and e.kind='settled')
 and p.fundraising_intent_id is not distinct from c.intent_id
 and p.payer_person_id is not distinct from c.actor_person_id and p.recorded_by_person_id is not distinct from c.actor_person_id
 and(c.state='captured_unallocated'and t.purpose='unallocated'and not exists(select 1 from public.payment_allocations a where a.payment_id=p.id)
 or c.state='completed'and c.purpose='fees'and t.purpose='fees'))then
 raise exception'External payment requires exact verified checkout evidence'using errcode='23514';end if;
 return null;
end$$;
create constraint trigger rails_external_payment_proof after insert on public.payments deferrable initially deferred for each row execute function boss_private.rails_external_payment_proof();

create function boss_private.rails_workflow_guard() returns trigger language plpgsql volatile security definer set search_path='' as $$begin
 if tg_op='DELETE' then raise exception'Payment history cannot be deleted' using errcode='23514';end if;
 if tg_table_name='processing_accounts' then
 if (to_jsonb(new)-array['name','capabilities','status','statement_descriptor','version','updated_at']) is distinct from (to_jsonb(old)-array['name','capabilities','status','statement_descriptor','version','updated_at']) then raise exception'Processing identity cannot change' using errcode='23514';end if;
 elsif tg_table_name='payment_checkouts' then
 if to_jsonb(new)-'state' is distinct from to_jsonb(old)-'state' then raise exception'Checkout identity cannot change' using errcode='23514';end if;
 elsif tg_table_name='provider_operations' then
 if to_jsonb(new)-array['state','dispatched_at','provider_transaction_reference'] is distinct from to_jsonb(old)-array['state','dispatched_at','provider_transaction_reference']
 or old.dispatched_at is not null and new.dispatched_at is distinct from old.dispatched_at
 or old.provider_transaction_reference is not null and new.provider_transaction_reference is distinct from old.provider_transaction_reference then raise exception'Provider operation identity cannot change' using errcode='23514';end if;
 elsif tg_table_name in('saved_payment_methods','payment_execution_consents') then
 if to_jsonb(new)-'revoked_at' is distinct from to_jsonb(old)-'revoked_at' or old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at then raise exception'Payment consent cannot rewrite' using errcode='23514';end if;
 elsif tg_table_name='payment_recurring_work' then
 if to_jsonb(new)-array['state','checkout_id'] is distinct from to_jsonb(old)-array['state','checkout_id'] or old.checkout_id is not null and old.checkout_id is distinct from new.checkout_id then raise exception'Recurring identity cannot change' using errcode='23514';end if;
 end if;return new;
end$$;
do $$declare t text;p record;begin
 foreach t in array array['processing_accounts','payment_checkouts','provider_operations','saved_payment_methods','payment_execution_consents','payment_recurring_work']loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.rails_workflow_guard()',t||'_guard',t);end loop;
 for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'rails_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;
end$$;
