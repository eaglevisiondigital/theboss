-- Main Boss Chat, October 7: card capture is payment success, independently of
-- settlement. Submitted attempts hold resources through natural clock expiry.
-- No provider credentials/worker login or production money movement is seeded.
alter table public.payment_checkouts drop constraint payment_checkouts_state_check;
alter table public.payment_checkouts add constraint payment_checkouts_state_check check(state in('ready','external_pending','unknown','authorized','ach_pending','review_required','completed','captured_unallocated','failed','canceled','expired','partially_refunded','refunded'));
drop index public.payment_checkouts_intent_open_idx;
create unique index payment_checkouts_intent_open_idx on public.payment_checkouts(intent_id) where state in('ready','external_pending','unknown','authorized','ach_pending','review_required','completed','captured_unallocated','partially_refunded','refunded');
alter table public.payment_checkout_events drop constraint payment_checkout_events_kind_check;
alter table public.payment_checkout_events add constraint payment_checkout_events_kind_check check(kind in('ready','dispatch','unknown','authorized','ach_pending','review_required','completed','captured_unallocated','failed','canceled','expired','refund','release'));
alter table public.payment_checkout_events add foreign key(operation_id) references public.provider_operations(id);

create table public.payment_eligibility_commits(
 checkout_id uuid primary key references public.payment_checkouts(id),
 operation_id uuid not null unique references public.provider_operations(id),
 organization_id uuid not null references public.organizations(id),
 eligibility_committed_at timestamptz not null default clock_timestamp(),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'),
 foreign key(organization_id,checkout_id) references public.payment_checkouts(organization_id,id),
 check(isfinite(eligibility_committed_at)));
create index payment_eligibility_commits_org_idx on public.payment_eligibility_commits(organization_id,eligibility_committed_at,checkout_id);
create table public.payment_attempt_invalidations(
 checkout_id uuid primary key references public.payment_checkouts(id),
 reason text not null check(reason in('definitive_failure','reviewed_cancel','detached','replaced')),
 event_id uuid references public.provider_event_evidence(id),actor_id uuid references public.people(id),
 created_at timestamptz not null default clock_timestamp(),
 check(reason<>'definitive_failure' or event_id is not null));
create index payment_attempt_invalidations_actor_idx on public.payment_attempt_invalidations(actor_id);
create index payment_attempt_invalidations_event_idx on public.payment_attempt_invalidations(event_id);
create table public.payment_review_cases(
 id uuid primary key default gen_random_uuid(),checkout_id uuid not null references public.payment_checkouts(id),
 event_id uuid not null references public.provider_event_evidence(id),
 reason text not null check(reason in('late_success','campaign_canceled','allocation_changed','evidence_mismatch','contradictory_status')),
 created_at timestamptz not null default clock_timestamp(),unique(checkout_id,event_id,reason));
create index payment_review_cases_event_idx on public.payment_review_cases(event_id);
-- Immutable chronology: a captured timestamp is never labeled settled.
alter table public.fundraising_success_evidence alter column settled_at drop not null;
alter table public.fundraising_success_evidence add column captured_at timestamptz;
alter table public.fundraising_success_evidence add column payment_success_at timestamptz generated always as(coalesce(captured_at,settled_at))stored;
alter table public.fundraising_success_evidence add constraint fundraising_method_success_time check(num_nonnulls(captured_at,settled_at)=1 and isfinite(coalesce(captured_at,settled_at)));

create function boss_private.rails_hold(checkout uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.payment_checkouts c where c.id=checkout and not exists(select 1 from public.payment_attempt_invalidations i where i.checkout_id=c.id)
 and (c.state='ready'and c.expires_at>clock_timestamp() or c.state in('external_pending','unknown','authorized','ach_pending','review_required')
 and exists(select 1 from public.provider_operations o where o.checkout_id=c.id and o.kind in('sale','authorize')and o.dispatched_at is not null)))
$$;
create or replace function boss_private.rails_grant_reserved(grant_uuid uuid)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce(sum(r.amount_minor),0)::bigint from public.boss_bucks_checkout_reservations r where r.grant_id=grant_uuid and boss_private.rails_hold(r.checkout_id)
$$;
create or replace function boss_private.rails_charge_reserved(charge uuid,except_checkout uuid default null)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce(sum(a.principal_minor),0)::bigint from public.checkout_charge_allocations a where a.charge_id=charge and a.checkout_id is distinct from except_checkout and boss_private.rails_hold(a.checkout_id)
$$;
create function boss_private.rails_tile_pending(tile uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.fundraising_intents i join public.payment_checkouts c on c.intent_id=i.id where i.tile_id=tile and c.state<>'ready'and boss_private.rails_hold(c.id))
$$;
create function boss_private.rails_tile_guard()returns trigger language plpgsql volatile security definer set search_path=''as $$begin
 perform 1 from public.money_board_tiles where id=new.tile_id for update;
 if (tg_op='INSERT'or new.released_at is distinct from old.released_at)and boss_private.rails_tile_pending(new.tile_id)then
 raise exception'Provider outcome unresolved; tile remains payment-pending'using errcode='PT409';end if;return new;
end$$;
create trigger rails_tile_hold before insert or update of released_at on public.money_board_reservations for each row execute function boss_private.rails_tile_guard();
-- Retain the existing trusted guest/board API and add pending-hold semantics.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.fundraising_guest(jsonb)'::regprocedure);
 if position('if exists(select 1 from public.fundraising_success_evidence where tile_id=t.id)or exists' in d)=0 then raise exception'Guest reservation checkpoint mismatch';end if;
 d:=replace(d,'if exists(select 1 from public.fundraising_success_evidence where tile_id=t.id)or exists','if boss_private.rails_tile_pending(t.id)or exists(select 1 from public.fundraising_success_evidence where tile_id=t.id)or exists');execute d;
 d:=pg_get_functiondef('boss_private.fundraising_board_projection(uuid,integer)'::regprocedure);
 d:=replace(d,'then''claimed''when exists','then''claimed''when boss_private.rails_tile_pending(t.id)then''payment_pending''when exists');execute d;
 d:=pg_get_functiondef('boss_private.fundraising_mutate(jsonb)'::regprocedure);
 -- Campaign archive must not silently drop possible money movement. The
 -- reservation trigger denies archive/release while a provider hold exists.
 if position('Claimed or reserved board cannot regenerate' in d)>0 then
 d:=replace(d,'if exists(select 1 from public.fundraising_success_evidence e join public.money_board_tiles t on t.id=e.tile_id where t.board_id=b.id)or exists',
 'if exists(select 1 from public.money_board_tiles t where t.board_id=b.id and boss_private.rails_tile_pending(t.id))or exists(select 1 from public.fundraising_success_evidence e join public.money_board_tiles t on t.id=e.tile_id where t.board_id=b.id)or exists');execute d;end if;
end$$;

-- Claim commits eligibility before the potentially successful external request.
-- Even if the process dies before sending, retain a conservative unknown hold;
-- definitive contract evidence or reviewed recovery is required to release it.
create function boss_private.rails_dispatch(checkout uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare c public.payment_checkouts;o public.provider_operations;x public.fundraising_intents;f public.fundraising_fundraisers;
 camp public.fundraising_campaigns;r public.money_board_reservations;leg record;s jsonb;committed timestamptz;begin
 c:=boss_private.rails_checkout_fence(checkout);
 select *into o from public.provider_operations where checkout_id=c.id and kind in('sale','authorize')for update;
 if o.id is not null and o.dispatched_at is not null then return jsonb_build_object('operation_id',o.id,'first_dispatch',false,'state',o.state,'transaction_reference',o.provider_transaction_reference,'provider_request_reference',o.provider_request_reference);end if;
 committed:=clock_timestamp();
 if c.state<>'ready' or c.expires_at<=committed or not boss_private.rails_feature(c.organization_id,'online_payments')
 or not boss_private.rails_account_ready(c.account_id,c.organization_id,c.method,c.currency)or not boss_private.rails_route_current(c.routing_id)then raise exception'Checkout eligibility ended'using errcode='PT409';end if;
 if c.actor_person_id is not null and not boss_private.rails_actor_current(c.actor_person_id)then raise exception'Payer authority ended'using errcode='PT403';end if;
 if c.purpose='fundraising'then
 select *into x from public.fundraising_intents where id=c.intent_id;
 select *into camp from public.fundraising_campaigns where id=x.campaign_id;
 select *into f from public.fundraising_fundraisers where id=x.fundraiser_id;
 if x.amount_minor<>c.principal_minor or x.currency<>c.currency or x.expires_at<=committed or not boss_private.fundraising_active(camp)
 or f.id is not null and not boss_private.fundraising_member(f) or not boss_private.rails_route_intent(c.routing_id,x.id)
 or exists(select 1 from public.fundraising_intent_events where intent_id=x.id and state<>'awaiting_payment')then raise exception'Contribution eligibility ended'using errcode='PT409';end if;
 if x.tile_id is not null then
 perform 1 from public.money_boards where id=x.board_id for update;perform 1 from public.money_board_tiles where id=x.tile_id for update;
 select *into r from public.money_board_reservations where id=x.reservation_id for update;
 if r.released_at is not null or r.expires_at<=committed or boss_private.rails_tile_pending(x.tile_id)
 or exists(select 1 from public.fundraising_success_evidence where tile_id=x.tile_id)or not exists(select 1 from public.money_boards where id=x.board_id and status='published')then raise exception'Tile eligibility ended'using errcode='PT409';end if;
 end if;
 else
 if not exists(select 1 from public.checkout_charge_allocations where checkout_id=c.id)or(select sum(principal_minor)from public.checkout_charge_allocations where checkout_id=c.id)<>c.principal_minor
 or(select sum(bucks_minor)from public.checkout_charge_allocations where checkout_id=c.id)<>c.bucks_minor then raise exception'Invalid canonical charge slices'using errcode='PT422';end if;
 for leg in select *from public.checkout_charge_allocations where checkout_id=c.id order by charge_id loop
 if not boss_private.rails_charge_authorized(c.actor_person_id,leg.charge_id)or not boss_private.rails_route_charge(c.routing_id,leg.charge_id)
 or (boss_private.registration_charge_balance(leg.charge_id)->>'balance_due_minor')::bigint-boss_private.rails_charge_reserved(leg.charge_id,c.id)<leg.principal_minor
 then raise exception'Charge eligibility ended'using errcode='PT409';end if;end loop;
 end if;
 if c.bucks_minor>0 then
 if not boss_private.bucks_accessible(c.actor_person_id,c.wallet_id,true)or not boss_private.bucks_payment_features(c.organization_id)
 or not boss_private.bucks_feature(c.organization_id,'split_tender')or(select coalesce(sum(amount_minor),0)from public.boss_bucks_checkout_reservations where checkout_id=c.id)<>c.bucks_minor then raise exception'Wallet eligibility ended'using errcode='PT409';end if;
 for leg in select g.*,b.amount_minor reserved from public.boss_bucks_checkout_reservations b join public.boss_bucks_grants g on g.id=b.grant_id where b.checkout_id=c.id order by g.id loop
 if leg.wallet_id<>c.wallet_id or leg.organization_id<>c.organization_id or leg.currency<>c.currency or leg.available_at>committed or leg.expires_at<=committed
 or boss_private.bucks_grant_book(leg.id)<leg.reserved+boss_private.rails_grant_reserved(leg.id)-leg.reserved then raise exception'Wallet slice changed'using errcode='PT409';end if;end loop;
 end if;
 if o.id is null then
 insert into public.provider_operations(organization_id,checkout_id,account_id,kind,request_id,provider_request_reference,amount_minor,currency)
 values(c.organization_id,c.id,c.account_id,'sale',c.request_id,substr(replace(c.request_id::text,'-',''),1,20),c.external_minor,c.currency)returning *into o;end if;
 s:=jsonb_build_object('checkout_id',c.id,'operation_id',o.id,'provider_account_id',c.account_id,'provider_request_reference',o.provider_request_reference,
 'organization_id',c.organization_id,'actor_person_id',c.actor_person_id,'purpose',c.purpose,'method',c.method,'currency',c.currency,
 'principal_minor',c.principal_minor,'external_minor',c.external_minor,'bucks_minor',c.bucks_minor,'routing_revision_id',c.routing_id,'settlement_policy_revision_id',c.policy_id,
 'wallet_id',c.wallet_id,'intent_id',c.intent_id,'campaign_id',x.campaign_id,'fundraiser_id',x.fundraiser_id,'board_id',x.board_id,'tile_id',x.tile_id,'reservation_id',x.reservation_id,
 'share_id',x.share_id,'attribution',x.provenance,'reward_policy',x.reward_policy,
 'earning_policy_revision_id',(select policy_revision_id from public.boss_bucks_source_snapshots where intent_id=x.id),
 'earning_household_id',(select household_id from public.boss_bucks_source_snapshots where intent_id=x.id),
 'fundraiser_binding',(select to_jsonb(b)from public.boss_bucks_fundraiser_bindings b where b.fundraiser_id=x.fundraiser_id),
 'earning_authorized',coalesce(boss_private.bucks_feature(c.organization_id,'fundraising_issuance')and boss_private.fundraising_module(c.organization_id,'fundraising')
 and exists(select 1 from public.boss_bucks_fundraiser_bindings b join public.boss_bucks_source_snapshots ss on ss.intent_id=x.id and ss.household_id=b.household_id
 where b.fundraiser_id=x.fundraiser_id and boss_private.bucks_guardian(b.authorized_by,f.person_id,b.household_id)),false),
 'charges',coalesce((select jsonb_agg(jsonb_build_object('charge_id',ca.charge_id,'participant_id',ch.participant_id,'principal_minor',ca.principal_minor,'bucks_minor',ca.bucks_minor)order by ca.charge_id)
 from public.checkout_charge_allocations ca join public.charges ch on ch.id=ca.charge_id where ca.checkout_id=c.id),'[]'),
 'grant_reservations',coalesce((select jsonb_agg(jsonb_build_object('grant_id',grant_id,'amount_minor',amount_minor)order by grant_id)from public.boss_bucks_checkout_reservations where checkout_id=c.id),'[]'));
 insert into public.payment_eligibility_commits(checkout_id,operation_id,organization_id,eligibility_committed_at,snapshot)values(c.id,o.id,c.organization_id,committed,s);
 update public.provider_operations set state='dispatched',dispatched_at=committed where id=o.id;
 update public.payment_checkouts set state='external_pending'where id=c.id;
 insert into public.payment_checkout_events(checkout_id,kind,operation_id)values(c.id,'dispatch',o.id);
 perform boss_private.rails_audit(c.actor_person_id,c.organization_id,'payment.attempt.dispatched',c.id,c.request_id,jsonb_build_object('operation_id',o.id,'eligibility_committed_at',committed));
 return jsonb_build_object('operation_id',o.id,'first_dispatch',true,'state','dispatched','provider_request_reference',o.provider_request_reference);
end$$;

create function boss_private.rails_invalidate(checkout uuid,reason text,event uuid default null,actor uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$declare c public.payment_checkouts;e public.provider_event_evidence;begin
 c:=boss_private.rails_checkout_fence(checkout);
 if exists(select 1 from public.payment_attempt_invalidations where checkout_id=c.id)then return;end if;
 if exists(select 1 from public.external_payment_tenders where checkout_id=c.id)then raise exception'Use explicit original-tender correction'using errcode='PT409';end if;
 if reason='definitive_failure'then
 select *into e from public.provider_event_evidence where id=event;
 if e.id is null or e.kind not in('failed','voided','returned')or e.kind='returned'and c.method<>'ach'or e.account_id<>c.account_id or not exists(select 1 from public.provider_operations where id=e.operation_id and checkout_id=c.id)
 then raise exception'Definitive provider failure evidence required'using errcode='PT422';end if;
 elsif reason not in('reviewed_cancel','detached','replaced')or actor is null or not boss_private.rails_role(actor,'settlements.reconcile',c.organization_id)or not boss_private.rails_actor_current(actor)then raise exception'Reviewed cancellation authority required'using errcode='PT403';end if;
 insert into public.payment_attempt_invalidations(checkout_id,reason,event_id,actor_id)values(c.id,reason,event,actor);
 update public.payment_checkouts set state=case when reason='definitive_failure'then'failed'else'canceled'end where id=c.id;
 update public.money_board_reservations set released_at=clock_timestamp(),release_reason='supporter_cancel'where id=(select reservation_id from public.fundraising_intents where id=c.intent_id)and released_at is null;
 insert into public.payment_checkout_events(checkout_id,kind)values(c.id,case when reason='definitive_failure'then'failed'else'canceled'end);
 perform boss_private.rails_audit(actor,c.organization_id,'payment.attempt.invalidated',c.id,null,jsonb_build_object('reason',reason,'event_id',event));
end$$;

-- Extend the same canonical trusted-success boundary. Historical integrations
-- keep their six-argument settled contract; the provider extension is closed and
-- requires an exact immutable committed attempt and method-specific evidence.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.fundraising_ingest_success(uuid,text,text,bigint,text,timestamptz)'::regprocedure);
 d:=replace(d,'settled_at timestamp with time zone)', 'settled_at timestamp with time zone, committed_checkout uuid)');
 if position('committed_checkout uuid)'in d)=0 then raise exception'Trusted-success signature checkpoint mismatch';end if;
 d:=replace(d,'qualified boolean;','qualified boolean; verified boolean:=false; capture_time timestamptz;commit_snapshot jsonb;');
 d:=replace(d,'if e.id is not null then',E'if committed_checkout is not null then\n select ec.snapshot into commit_snapshot from public.payment_eligibility_commits ec join public.payment_checkouts pc on pc.id=ec.checkout_id where pc.id=committed_checkout and pc.intent_id=x.id and pc.state in(''external_pending'',''unknown'',''authorized'',''ach_pending'',''review_required'')and not exists(select 1 from public.payment_attempt_invalidations inv where inv.checkout_id=pc.id)and exists(select 1 from public.provider_operations op join public.provider_event_evidence ev on ev.operation_id=op.id and ev.account_id=op.account_id where op.id=ec.operation_id and op.state=''succeeded''and ev.amount_minor=pc.external_minor and ev.currency=pc.currency and ev.transaction_reference=op.provider_transaction_reference and ev.occurred_at=settled_at and(pc.method=''card''and ev.kind in(''captured'',''settled'')or pc.method=''ach''and ev.kind=''settled''));\n verified:=commit_snapshot is not null;\n if not verified then raise exception''Verified committed provider success required''using errcode=''PT422'';end if;\n if (select method from public.payment_checkouts where id=committed_checkout)=''card'' then capture_time:=settled_at;end if;\n end if;\n if e.id is not null then');
 d:=replace(d,'e.settled_at<>settled_at','e.payment_success_at<>settled_at');
 d:=replace(d,'or x.expires_at<=clock_timestamp()','or not verified and x.expires_at<=clock_timestamp()');
 d:=replace(d,'if not boss_private.fundraising_active(c)or f.id is not null and not boss_private.fundraising_member(f)or x.tile_id is not null and(r.released_at is not null or r.expires_at<=clock_timestamp()or b.status<>''published''or not boss_private.fundraising_module(c.organization_id,''money_board'')or exists',
 'if not verified and(not boss_private.fundraising_active(c)or f.id is not null and not boss_private.fundraising_member(f))or verified and (c.status not in(''active'',''scheduled'',''completed'')or c.status=''completed''and c.ends_at>clock_timestamp())or x.tile_id is not null and(r.released_at is not null or not verified and(r.expires_at<=clock_timestamp()or b.status<>''published''or not boss_private.fundraising_module(c.organization_id,''money_board''))or exists');
 d:=replace(d,'provenance,settled_at)values','provenance,settled_at,captured_at)values');
 d:=replace(d,'''reward_policy'',x.reward_policy),settled_at)','''reward_policy'',x.reward_policy,''committed_checkout_id'',committed_checkout),case when capture_time is null then settled_at end,capture_time)');
 execute d;
end$$;
-- Six-argument legacy entry stays unchanged, including its settled-only contract.
-- The overload shares its canonical insertion, notifications and wallet triggers.
-- Payment success time drives earnings; no captured timestamp is misrepresented.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.bucks_issue(uuid)'::regprocedure);
 d:=replace(d,'e.settled_at','e.payment_success_at');
 d:=replace(d,'amount bigint;begin','amount bigint;committed jsonb;begin');
 d:=replace(d,'if not boss_private.bucks_feature(c.organization_id,''fundraising_issuance'')or not boss_private.fundraising_module(c.organization_id,''fundraising'')then return null;end if;',
 E'select ec.snapshot into committed from public.payment_eligibility_commits ec where ec.checkout_id=(e.provenance->>''committed_checkout_id'')::uuid;\n if committed is null then\n if not boss_private.bucks_feature(c.organization_id,''fundraising_issuance'')or not boss_private.fundraising_module(c.organization_id,''fundraising'')then return null;end if;\n elsif committed->''earning_authorized'' is distinct from ''true''::jsonb then return null;end if;');
 d:=replace(d,'if not boss_private.bucks_guardian(b.authorized_by,f.person_id,s.household_id)then return null;end if;','if committed is null and not boss_private.bucks_guardian(b.authorized_by,f.person_id,s.household_id)then return null;end if;');execute d;
end$$;
-- Separate method-specific times in every existing supporter/finance projection.
do $$declare d text;sig regprocedure;begin
 foreach sig in array array['boss_private.fundraising_public_read(text,integer)'::regprocedure,'boss_private.fundraising_read(jsonb)'::regprocedure]loop
 d:=pg_get_functiondef(sig);d:=replace(d,'e.settled_at','e.payment_success_at');
 d:=replace(d,'order by settled_at','order by payment_success_at');
 d:=replace(d,'''settled_at'',e.payment_success_at','''payment_success_at'',e.payment_success_at,''captured_at'',e.captured_at,''settled_at'',e.settled_at');execute d;end loop;
end$$;

do $$declare t text;p record;begin
 foreach t in array array['payment_eligibility_commits','payment_attempt_invalidations','payment_review_cases']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);
 execute format('create trigger immutable_%I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t,t);
 execute format('create trigger immutable_truncate_%I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t,t);end loop;
 for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and(proname like'rails_%'or proname='fundraising_ingest_success')loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;
end$$;

create function boss_private.rails_commit_reserved_bucks(c public.payment_checkouts)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare p uuid:=gen_random_uuid();a record;gr record;allocation uuid;ids uuid[]:='{}';lefts bigint[]:='{}';ix integer:=1;j uuid;take bigint;chunk bigint;ordinal integer:=0;begin
 if c.bucks_minor=0 then return null;end if;
 -- Same Phase 7C journals, consumptions, proof constraints and source lineage.
 -- Commit precisely the reserved slices rather than rerunning mutable FEFO.
 insert into public.payments(id,organization_id,method,amount_minor,currency,payer_person_id,received_at,recorded_by_person_id,source_reference)
 values(p,c.organization_id,'boss_bucks',c.bucks_minor,c.currency,c.actor_person_id,clock_timestamp(),c.actor_person_id,c.request_id::text);
 insert into public.boss_bucks_tenders(payment_id,wallet_id,organization_id,currency,actor_person_id,request_id,checkout_id)
 values(p,c.wallet_id,c.organization_id,c.currency,c.actor_person_id,c.request_id,c.id);
 for a in select *from public.checkout_charge_allocations where checkout_id=c.id and bucks_minor>0 order by charge_id loop
 insert into public.payment_allocations(organization_id,payment_id,charge_id,amount_minor)values(c.organization_id,p,a.charge_id,a.bucks_minor)returning id into allocation;
 ids:=array_append(ids,allocation);lefts:=array_append(lefts,a.bucks_minor);end loop;
 for gr in select g.*,r.amount_minor reserved from public.boss_bucks_checkout_reservations r join public.boss_bucks_grants g on g.id=r.grant_id where r.checkout_id=c.id order by g.expires_at nulls last,g.available_at,g.created_at,g.id loop
 j:=boss_private.bucks_pair(gr.id,'spend',gr.reserved,'Canonical submitted split tender');take:=gr.reserved;ordinal:=ordinal+1;
 while take>0 loop chunk:=least(take,lefts[ix]);
 insert into public.boss_bucks_consumptions(allocation_id,grant_id,journal_id,amount_minor,ordinal)values(ids[ix],gr.id,j,chunk,ordinal);
 take:=take-chunk;lefts[ix]:=lefts[ix]-chunk;if lefts[ix]=0 then ix:=ix+1;end if;end loop;end loop;
 perform boss_private.bucks_audit(c.actor_person_id,'boss_bucks.payment.spend',c.organization_id,c.wallet_id,null,c.request_id,jsonb_build_object('payment_id',p,'checkout_id',c.id,'amount_minor',c.bucks_minor));return p;
end$$;

create function boss_private.rails_complete(checkout uuid,event uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare c public.payment_checkouts;o public.provider_operations;e public.provider_event_evidence;ec public.payment_eligibility_commits;
 payment uuid;funding uuid;buckspayment uuid;why text;a record;g record;begin
 c:=boss_private.rails_checkout_fence(checkout);
 select *into ec from public.payment_eligibility_commits where checkout_id=c.id;
 select *into o from public.provider_operations where id=ec.operation_id for update;
 select *into e from public.provider_event_evidence where id=event;
 if ec.checkout_id is null or e.id is null or e.operation_id is distinct from o.id or e.account_id<>c.account_id
 or e.amount_minor<>c.external_minor or e.currency<>c.currency or e.transaction_reference is distinct from o.provider_transaction_reference
 or e.occurred_at<ec.eligibility_committed_at or not(c.method='card'and e.kind in('captured','settled')or c.method='ach'and e.kind='settled')then raise exception'Verified method-specific payment evidence required'using errcode='PT422';end if;
 select payment_id into payment from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null;
 if payment is not null then return jsonb_build_object('payment_id',payment,'state',c.state,'replayed',true);end if;
 if exists(select 1 from public.payment_attempt_invalidations where checkout_id=c.id)or c.state in('failed','canceled','expired','refunded','partially_refunded')then why:='late_success';end if;
 if c.intent_id is not null then
 if exists(select 1 from public.fundraising_campaigns ca join public.fundraising_intents fi on fi.campaign_id=ca.id where fi.id=c.intent_id
 and (ca.status not in('active','scheduled','completed')or ca.status='completed'and ca.ends_at>clock_timestamp()))then why:=coalesce(why,'campaign_canceled');end if;
 if exists(select 1 from public.fundraising_intent_events where intent_id=c.intent_id and state<>'awaiting_payment')or exists(select 1 from public.fundraising_intents fi join public.money_board_reservations r on r.id=fi.reservation_id where fi.id=c.intent_id and r.released_at is not null)
 or exists(select 1 from public.fundraising_success_evidence where tile_id=(select tile_id from public.fundraising_intents where id=c.intent_id))then why:=coalesce(why,'late_success');end if;
 else
 for a in select *from public.checkout_charge_allocations where checkout_id=c.id order by charge_id loop
 if not exists(select 1 from public.charges where id=a.charge_id and status='active')or (boss_private.registration_charge_balance(a.charge_id)->>'balance_due_minor')::bigint-boss_private.rails_charge_reserved(a.charge_id,c.id)<a.principal_minor then why:=coalesce(why,'allocation_changed');end if;end loop;
 for g in select gr.*,r.amount_minor reserved from public.boss_bucks_checkout_reservations r join public.boss_bucks_grants gr on gr.id=r.grant_id where r.checkout_id=c.id loop
 if g.expires_at<=clock_timestamp()or boss_private.bucks_grant_book(g.id)<g.reserved or g.wallet_id<>c.wallet_id or g.organization_id<>c.organization_id then why:=coalesce(why,'allocation_changed');end if;end loop;
 end if;
 update public.provider_operations set state='succeeded'where id=o.id;
 if why is null and c.intent_id is not null then
 funding:=boss_private.fundraising_ingest_success(c.intent_id,'provider:'||(select provider from public.processing_accounts where id=c.account_id)||':'||c.account_id,e.transaction_reference,c.principal_minor,c.currency,e.occurred_at,c.id);
 end if;
 update public.payment_checkouts set state=case when why is null then'completed'else'captured_unallocated'end where id=c.id;
 if why is null then buckspayment:=boss_private.rails_commit_reserved_bucks(c);end if;
 insert into public.payments(organization_id,method,amount_minor,currency,payer_person_id,recorded_by_person_id,received_at,source_reference,fundraising_intent_id)
 values(c.organization_id,c.method,c.external_minor,c.currency,c.actor_person_id,c.actor_person_id,e.occurred_at,e.transaction_reference,c.intent_id)returning id into payment;
 insert into public.external_payment_tenders(payment_id,organization_id,checkout_id,operation_id,event_id,purpose)
 values(payment,c.organization_id,c.id,o.id,e.id,case when why is null then c.purpose else'unallocated'end);
 if why is null and c.purpose='fees'then
 insert into public.payment_allocations(organization_id,payment_id,charge_id,amount_minor)
 select c.organization_id,payment,charge_id,principal_minor-bucks_minor from public.checkout_charge_allocations where checkout_id=c.id and principal_minor>bucks_minor;
 end if;
 if why is not null then insert into public.payment_review_cases(checkout_id,event_id,reason)values(c.id,e.id,why)on conflict do nothing;end if;
 insert into public.payment_checkout_events(checkout_id,kind,operation_id)values(c.id,case when why is null then'completed'else'captured_unallocated'end,o.id);
 perform boss_private.rails_audit(c.actor_person_id,c.organization_id,'payment.success',c.id,c.request_id,jsonb_build_object('payment_id',payment,'fundraising_evidence_id',funding,'bucks_payment_id',buckspayment,'review_reason',why,'payment_success_at',e.occurred_at));
 return jsonb_build_object('payment_id',payment,'state',case when why is null then'completed'else'captured_unallocated'end,'replayed',false);
end$$;

create function boss_private.rails_receive(checkout uuid,p_event_reference text,p_kind text,p_transaction_reference text,p_amount bigint,p_currency text,p_occurred_at timestamptz,p_digest text,p_metadata jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare c public.payment_checkouts;o public.provider_operations;e public.provider_event_evidence;prior public.provider_event_evidence;v_state text;begin
 c:=boss_private.rails_checkout_fence(checkout);
 select *into o from public.provider_operations where checkout_id=c.id and kind in('sale','authorize')for update;
 if o.id is null or o.dispatched_at is null then raise exception'Submitted operation required'using errcode='PT409';end if;
 if p_kind not in('authorized','captured','settled','ach_pending','failed','unknown','returned','voided','refunded','disputed','dispute_won','batch')
 or p_amount<>c.external_minor or p_currency<>c.currency or p_occurred_at<o.dispatched_at
 or p_transaction_reference is null and p_kind not in('unknown','failed')or o.provider_transaction_reference is not null and p_transaction_reference is distinct from o.provider_transaction_reference
 or jsonb_typeof(p_metadata)is distinct from'object'or exists(select 1 from jsonb_object_keys(p_metadata)k where k<>all(array['response_code','risk_code','batch_reference','processor_fee_minor','failure_contract','status_code']))
 or length(p_metadata::text)>1200 then raise exception'Normalized provider evidence mismatch'using errcode='PT422';end if;
 -- An unknown transport timeout is never promoted to provider failure. A
 -- not-found result must be certified definitive under the account contract.
 if p_kind='failed'and coalesce(p_metadata->>'failure_contract','')not in('definitive_decline','definitive_failure','definitive_not_found')then raise exception'Definitive failure contract required'using errcode='PT422';end if;
 select *into prior from public.provider_event_evidence where account_id=c.account_id and event_reference=p_event_reference;
 if prior.id is not null then
 if prior.operation_id<>o.id or prior.kind<>p_kind or prior.body_digest<>p_digest or prior.amount_minor<>p_amount or prior.currency<>p_currency
 or prior.transaction_reference<>coalesce(p_transaction_reference,'unresolved:'||o.provider_request_reference)or prior.occurred_at<>p_occurred_at or prior.safe_metadata<>p_metadata then raise exception'Provider event replay conflict'using errcode='PT409';end if;
 return jsonb_build_object('state',c.state,'replayed',true);end if;
 insert into public.provider_event_evidence(account_id,operation_id,event_reference,kind,transaction_reference,amount_minor,currency,occurred_at,body_digest,safe_metadata)
 values(c.account_id,o.id,p_event_reference,p_kind,coalesce(p_transaction_reference,'unresolved:'||o.provider_request_reference),p_amount,p_currency,p_occurred_at,p_digest,p_metadata)returning *into e;
 if p_transaction_reference is not null then update public.provider_operations set provider_transaction_reference=p_transaction_reference where id=o.id;end if;
 if p_kind in('captured','settled')and(c.method='card'or p_kind='settled')then return boss_private.rails_complete(c.id,e.id);end if;
 if c.state in('completed','captured_unallocated','partially_refunded','refunded')or exists(select 1 from public.payment_attempt_invalidations where checkout_id=c.id)then
 if p_kind in('unknown','failed','authorized','ach_pending')then insert into public.payment_review_cases(checkout_id,event_id,reason)values(c.id,e.id,'contradictory_status');end if;
 return jsonb_build_object('state',c.state,'replayed',false,'event_id',e.id);end if;
 if p_kind in('failed','voided','returned')then
 perform boss_private.rails_invalidate(c.id,'definitive_failure',e.id);update public.provider_operations set state='failed'where id=o.id;
 return jsonb_build_object('state','failed','replayed',false);end if;
 v_state:=case p_kind when'authorized'then'authorized'when'ach_pending'then'ach_pending'else'unknown'end;
 update public.provider_operations set state=v_state where id=o.id;
 update public.payment_checkouts set state=v_state where id=c.id;
 insert into public.payment_checkout_events(checkout_id,kind,operation_id)values(c.id,v_state,o.id);
 return jsonb_build_object('state',v_state,'replayed',false,'event_id',e.id);
end$$;

create or replace function boss_private.rails_external_payment_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare p public.payments;begin
 select *into p from public.payments where id=case when tg_table_name='payments'then(to_jsonb(new)->>'id')::uuid else(to_jsonb(new)->>'payment_id')::uuid end;
 if p.method not in('card','ach')then return null;end if;
 if not exists(select 1 from public.external_payment_tenders t join public.payment_checkouts c on c.id=t.checkout_id and c.organization_id=t.organization_id
 join public.payment_eligibility_commits ec on ec.checkout_id=c.id and ec.operation_id=t.operation_id
 join public.provider_operations o on o.id=t.operation_id and o.checkout_id=c.id and o.account_id=c.account_id and o.organization_id=c.organization_id
 join public.provider_event_evidence e on e.id=t.event_id and e.account_id=c.account_id and e.operation_id=o.id
 where t.payment_id=p.id and t.organization_id=p.organization_id and t.original_payment_id is null and p.reversal_of_id is null and p.status='recorded'
 and o.kind in('sale','capture')and o.state='succeeded'and e.transaction_reference=o.provider_transaction_reference and e.amount_minor=p.amount_minor and p.amount_minor=c.external_minor
 and e.currency=p.currency and p.currency=c.currency and p.method=c.method and e.occurred_at>=ec.eligibility_committed_at
 and(p.method='card'and e.kind in('captured','settled')or p.method='ach'and e.kind='settled')
 and p.fundraising_intent_id is not distinct from c.intent_id and p.payer_person_id is not distinct from c.actor_person_id and p.recorded_by_person_id is not distinct from c.actor_person_id
 and(c.state='captured_unallocated'and t.purpose='unallocated'and not exists(select 1 from public.payment_allocations where payment_id=p.id)
 or c.state in('completed','partially_refunded','refunded')and t.purpose=c.purpose and(c.purpose='fees'or exists(select 1 from public.fundraising_success_evidence fe where fe.intent_id=c.intent_id and fe.provenance->>'committed_checkout_id'=c.id::text)))
 )then raise exception'External payment requires exact verified checkout evidence'using errcode='23514';end if;return null;
end$$;
create constraint trigger rails_external_tender_proof after insert on public.external_payment_tenders deferrable initially deferred for each row execute function boss_private.rails_external_payment_proof();
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'rails_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;
