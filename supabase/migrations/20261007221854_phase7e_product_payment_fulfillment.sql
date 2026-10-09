-- Product orders join the existing rails. No new processor/worker/secret path.
alter table public.payment_checkouts drop constraint payment_checkouts_purpose_check;
alter table public.payment_checkouts add constraint payment_checkouts_purpose_check check(purpose in('fees','fundraising','products'));
alter table public.payment_routing_revisions drop constraint payment_routing_revisions_purpose_check;
alter table public.payment_routing_revisions add constraint payment_routing_revisions_purpose_check check(purpose in('fees','fundraising','products'));
alter table public.settlement_policy_revisions drop constraint settlement_policy_revisions_purpose_check;
alter table public.settlement_policy_revisions add constraint settlement_policy_revisions_purpose_check check(purpose in('fees','fundraising','boss_bucks','products'));
alter table public.external_payment_tenders drop constraint external_payment_tenders_purpose_check;
alter table public.external_payment_tenders add constraint external_payment_tenders_purpose_check check(purpose in('fees','fundraising','products','unallocated'));
alter table public.settlement_sources drop constraint settlement_sources_purpose_check;
alter table public.settlement_sources add constraint settlement_sources_purpose_check check(purpose in('fees','fundraising','boss_bucks','products','unallocated'));

create table public.discount_orders(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),buyer_person_id uuid references public.people(id),
 subject_type text not null check(subject_type in('person','household')),subject_id uuid,campaign_id uuid,fundraiser_id uuid,share_id uuid references public.fundraising_shares(id),
 channel text not null check(channel in('direct','fundraising')),revision_id uuid not null references public.discount_product_revisions(id),
 quantity integer not null check(quantity between 1 and 100),currency text not null check(currency~'^[A-Z]{3}$'),total_minor bigint not null check(total_minor between 1 and 1000000000),
 base_source_id uuid references public.discount_member_sources(id),checkout_id uuid unique references public.payment_checkouts(id),payment_id uuid unique references public.payments(id),
 request_id uuid not null unique,command_digest text not null check(command_digest~'^[a-f0-9]{64}$'),guest_digest text unique check(guest_digest~'^[a-f0-9]{64}$'),
 state text not null default 'payment_pending'check(state in('created','payment_pending','paid','fulfillment_pending','partially_fulfilled','fulfilled','canceled','partially_refunded','refunded','review')),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(campaign_id,fundraiser_id)references public.fundraising_fundraisers(campaign_id,id),
 check((channel='fundraising')=(campaign_id is not null)),check((buyer_person_id is null)=(guest_digest is not null)),check(subject_id is null or buyer_person_id is not null));
-- Guest commercial identity is this exact canonical order, never a guessed
-- Boss person. Other payment methods retain their original payer boundaries.
alter table public.payments add column product_order_id uuid references public.discount_orders(id);
alter table public.payments drop constraint payments_payer_boundary;
alter table public.payments add constraint payments_payer_boundary check(
 method in('card','ach')and(payer_person_id is not null or fundraising_intent_id is not null or product_order_id is not null)
 or method in('cash','check','boss_bucks')and payer_person_id is not null and recorded_by_person_id is not null and fundraising_intent_id is null and product_order_id is null);
create index payments_product_order_idx on public.payments(product_order_id);
create trigger discount_payment_order_identity before update on public.payments for each row execute function boss_private.preserve_row_identity('product_order_id');
create index discount_orders_org_idx on public.discount_orders(organization_id,created_at desc,id);
create index discount_orders_buyer_idx on public.discount_orders(buyer_person_id,created_at desc,id);
create index discount_orders_campaign_idx on public.discount_orders(campaign_id,fundraiser_id,created_at desc,id);
create index discount_orders_fundraiser_idx on public.discount_orders(fundraiser_id);
create index discount_orders_revision_idx on public.discount_orders(revision_id);
create index discount_orders_share_idx on public.discount_orders(share_id);
create index discount_orders_base_idx on public.discount_orders(base_source_id);
create table public.discount_order_items(
 id uuid primary key default gen_random_uuid(),order_id uuid not null references public.discount_orders(id),ordinal integer not null,
 product_id uuid not null references public.discount_products(id),revision_id uuid not null references public.discount_product_revisions(id),
 kind text not null check(kind in('digital','physical','state_upgrade','nationwide_upgrade')),
 price_minor bigint not null check(price_minor>0),organization_credit_minor bigint not null check(organization_credit_minor>=0),
 platform_retained_minor bigint not null check(platform_retained_minor>=0),product_cost_minor bigint not null check(product_cost_minor>=0),
 tier text not null check(tier in('local','state','nationwide')),fulfillment_type text not null check(fulfillment_type in('digital','shipping','pickup')),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'),source_id uuid unique references public.discount_member_sources(id),
 created_at timestamptz not null default clock_timestamp(),unique(order_id,ordinal),check(price_minor=organization_credit_minor+platform_retained_minor+product_cost_minor));
create index discount_order_items_revision_idx on public.discount_order_items(revision_id);
create index discount_order_items_product_idx on public.discount_order_items(product_id);
alter table public.discount_physical_cards add constraint discount_card_order_item_fk foreign key(order_item_id)references public.discount_order_items(id);
create table public.discount_order_history(
 id uuid primary key default gen_random_uuid(),order_id uuid not null references public.discount_orders(id),item_id uuid references public.discount_order_items(id),
 kind text not null check(kind in('created','paid','fulfilled','canceled','refunded','chargeback','review')),source_key text not null unique,
 source_event_id uuid,created_at timestamptz not null default clock_timestamp());
create index discount_order_history_order_idx on public.discount_order_history(order_id,created_at,id);
create index discount_order_history_item_idx on public.discount_order_history(item_id);
create table public.discount_fulfillments(
 id uuid primary key default gen_random_uuid(),item_id uuid not null unique references public.discount_order_items(id),card_id uuid unique references public.discount_physical_cards(id),
 state text not null check(state in('awaiting_inventory','allocated','ready_for_pickup','packed','shipped','delivered','canceled')),
 version bigint not null default 1,created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp());
create table public.discount_fulfillment_history(
 id uuid primary key default gen_random_uuid(),fulfillment_id uuid not null references public.discount_fulfillments(id),actor_id uuid references public.people(id),
 state text not null check(state in('awaiting_inventory','allocated','ready_for_pickup','packed','shipped','delivered','canceled')),created_at timestamptz not null default clock_timestamp());
create index discount_fulfillment_history_source_idx on public.discount_fulfillment_history(fulfillment_id,created_at,id);
create index discount_fulfillment_history_actor_idx on public.discount_fulfillment_history(actor_id);
create table boss_private.discount_delivery_contacts(
 order_id uuid primary key references public.discount_orders(id),email text check(length(email)<=254),
 address jsonb check(jsonb_typeof(address)='object'and octet_length(address::text)<=4096),created_at timestamptz not null default clock_timestamp());
create table public.discount_product_credits(
 id uuid primary key default gen_random_uuid(),item_id uuid not null references public.discount_order_items(id),payment_id uuid not null references public.payments(id),
 campaign_id uuid not null references public.fundraising_campaigns(id),fundraiser_id uuid references public.fundraising_fundraisers(id),
 amount_minor bigint not null,source_key text not null unique,source_event_id uuid,created_at timestamptz not null default clock_timestamp());
create index discount_product_credits_campaign_idx on public.discount_product_credits(campaign_id,fundraiser_id,id);
create index discount_product_credits_item_idx on public.discount_product_credits(item_id);
create index discount_product_credits_payment_idx on public.discount_product_credits(payment_id);
create index discount_product_credits_fundraiser_idx on public.discount_product_credits(fundraiser_id);
create table public.discount_refund_items(
 refund_id uuid not null references public.payment_refund_requests(id),item_id uuid not null references public.discount_order_items(id),
 primary key(refund_id,item_id),created_at timestamptz not null default clock_timestamp());
create index discount_refund_items_item_idx on public.discount_refund_items(item_id,refund_id);

create function boss_private.discount_order_prepare(actor uuid,command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb:=command->'input';request uuid:=(command->>'request_id')::uuid;revision public.discount_product_revisions;product public.discount_products;
 r public.payment_routing_revisions;o public.discount_orders;c public.payment_checkouts;f public.fundraising_fundraisers;ctx jsonb;subject uuid;base public.discount_member_sources;
 org uuid;campaign uuid;fundraiser uuid;share uuid;n integer;h text;cap text;binding public.discount_campaign_products;begin
 perform boss_private.athlete_input(i,array['revision_id','organization_id','quantity','method','path','household_id','base_source_id','capability','email','address'],array['revision_id','organization_id','quantity','method']);
 if i?'email'and(jsonb_typeof(i->'email')<>'string'or length(i->>'email')not between 1 and 254 or i->>'email'~'[[:cntrl:]]')then raise exception'Invalid delivery contact'using errcode='PT422';end if;
 if i?'address'then
 if jsonb_typeof(i->'address')<>'object'then raise exception'Invalid delivery address'using errcode='PT422';end if;
 if exists(select 1 from jsonb_each(i->'address')e where e.key not in('recipient','line1','line2','city','region','postal_code','country')or jsonb_typeof(e.value)<>'string'or length(e.value#>>'{}')>200 or e.value#>>'{}'~'[[:cntrl:]]')then raise exception'Invalid delivery address'using errcode='PT422';end if;
 end if;
 org:=(i->>'organization_id')::uuid;n:=(i->>'quantity')::integer;h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');
 if actor is null and coalesce(i->>'path','')=''then raise exception'Public product context required'using errcode='PT404';end if;
 if actor is null then if coalesce(i->>'capability','')!~'^[a-f0-9]{64}$'then raise exception'Purchase capability required'using errcode='PT422';end if;cap:=encode(sha256(convert_to(i->>'capability','UTF8')),'hex');end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-product-request:'||request,0));
 select *into o from public.discount_orders where request_id=request;

 select *into revision from public.discount_product_revisions where id=(i->>'revision_id')::uuid;
 if i->>'path'is not null then ctx:=boss_private.fundraising_public_context(i->>'path');campaign:=(ctx->>'campaign_id')::uuid;fundraiser:=(ctx->>'fundraiser_id')::uuid;share:=(ctx->>'share_id')::uuid;
 select *into binding from public.discount_campaign_products where campaign_id=campaign and revision_id=revision.id and sale_enabled and status='active'and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp())order by created_at desc,id desc limit 1;
 perform 1 from public.fundraising_campaigns where id=campaign and organization_id=org for update;
 if fundraiser is not null then select *into f from public.fundraising_fundraisers where id=fundraiser for update;end if;end if;
 perform boss_private.discount_fence(actor,org,(i->>'household_id')::uuid);
 perform 1 from public.discount_product_revisions where id=revision.id for share;
 if revision.id is null or revision.organization_id is distinct from org or not boss_private.discount_revision_active(revision.id)
 or not boss_private.discount_feature(org,'membership_sales')or not boss_private.discount_feature(org,'discount_membership')or not boss_private.rails_feature(org,'online_payments')
 or actor is not null and not boss_private.rails_actor_current(actor)or n not between 1 and 100 or i->>'method'not in('card','ach')
 or not(case when campaign is null then'direct'=any(revision.sale_channels)else'fundraising'=any(revision.sale_channels)and binding.id is not null
 and exists(select 1 from public.fundraising_campaigns ca where ca.id=campaign and ca.organization_id=org and boss_private.fundraising_active(ca))
 and(f.id is null or boss_private.fundraising_member(f))end)then raise exception'Product checkout is unavailable'using errcode='PT409';end if;
 select *into product from public.discount_products where id=revision.product_id;
 subject:=case when actor is null or n<>1 then null when revision.subject_type='person'then actor else(i->>'household_id')::uuid end;
 if actor is not null and n=1 and not boss_private.discount_subject(actor,revision.subject_type,subject,true)then raise exception'Product subject denied'using errcode='PT403';end if;
 if product.kind in('state_upgrade','nationwide_upgrade')then
 select *into base from public.discount_member_sources where id=(i->>'base_source_id')::uuid;
 if n<>1 or subject is null or not boss_private.discount_source_valid(base.id)or base.kind='tier_upgrade'
 or not exists(select 1 from public.discount_memberships m where m.id=base.membership_id and m.product_id=revision.membership_product_id and m.subject_type=revision.subject_type
 and m.subject_id=subject and m.country=revision.country and m.region=revision.region and m.market=revision.market)
 or not(boss_private.discount_effective(base.membership_id)->>'tier'=any(revision.upgrade_from_tiers))
 or boss_private.discount_tier_rank(revision.tier)<=boss_private.discount_tier_rank(boss_private.discount_effective(base.membership_id)->>'tier')
 or not boss_private.discount_feature(org,'membership_upgrades')then raise exception'Eligible underlying membership required'using errcode='PT409';end if;
 elsif i->>'base_source_id'is not null then raise exception'Unexpected upgrade source'using errcode='PT422';end if;
 select *into r from public.payment_routing_revisions where organization_id=org and purpose='products'and currency=revision.currency and boss_private.rails_route_current(id)
 and(scope_type='organization'and scope_id=org or scope_type='campaign'and scope_id=campaign)
 and boss_private.rails_account_ready(account_id,org,i->>'method',revision.currency)order by case scope_type when'campaign'then 0 else 1 end,revision desc limit 1;
 if r.id is null or revision.settlement_policy_id is null then raise exception'External product payment is unavailable'using errcode='PT409';end if;
 if o.id is not null then if o.buyer_person_id is distinct from actor or o.command_digest<>h then raise exception'Purchase replay conflict'using errcode='PT409';end if;return jsonb_build_object('order_id',o.id,'checkout_id',o.checkout_id,'state',o.state,'replayed',true);end if;
 perform boss_private.rails_rate('product:'||org,120);
 insert into public.discount_orders(organization_id,buyer_person_id,subject_type,subject_id,campaign_id,fundraiser_id,share_id,channel,revision_id,quantity,currency,total_minor,base_source_id,request_id,command_digest,guest_digest)
 values(org,actor,revision.subject_type,subject,campaign,fundraiser,share,case when campaign is null then'direct'else'fundraising'end,revision.id,n,revision.currency,revision.price_minor*n,base.id,request,h,cap)returning *into o;
 insert into public.discount_order_items(order_id,ordinal,product_id,revision_id,kind,price_minor,organization_credit_minor,platform_retained_minor,product_cost_minor,tier,fulfillment_type,snapshot)
 select o.id,ordinal,product.id,revision.id,product.kind,revision.price_minor,revision.organization_credit_minor,revision.platform_retained_minor,revision.product_cost_minor,revision.tier,revision.fulfillment_type,
 to_jsonb(revision)||jsonb_build_object('campaign_id',campaign,'fundraiser_id',fundraiser,'team_id',f.team_id,'unit_id',f.unit_id,'share_id',share,'channel',o.channel)from generate_series(1,n)ordinal;
 if i->>'email'is not null or i->'address'is not null then insert into boss_private.discount_delivery_contacts(order_id,email,address)values(o.id,i->>'email',i->'address');end if;
 insert into public.payment_checkouts(organization_id,actor_person_id,purpose,currency,account_id,routing_id,policy_id,method,principal_minor,external_minor,request_id,command_hash,capability_digest,expires_at)
 values(org,actor,'products',o.currency,r.account_id,r.id,revision.settlement_policy_id,i->>'method',o.total_minor,o.total_minor,request,h,cap,clock_timestamp()+interval'10 minutes')returning *into c;
 update public.discount_orders set checkout_id=c.id where id=o.id;
 insert into public.payment_checkout_events(checkout_id,kind)values(c.id,'ready');insert into public.discount_order_history(order_id,kind,source_key)values(o.id,'created','create:'||o.id);
 perform boss_private.discount_audit(actor,org,null,'product.order.created',o.id,request,jsonb_build_object('total_minor',o.total_minor,'quantity',n,'payment_state','pending'));
 return jsonb_build_object('order_id',o.id,'checkout_id',c.id,'state',o.state,'replayed',false);
end$$;
create function boss_private.discount_order_dispatch(checkout uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare o public.discount_orders;r public.discount_product_revisions;ctx jsonb;begin
 select *into o from public.discount_orders where checkout_id=checkout for update;select *into r from public.discount_product_revisions where id=o.revision_id;
 if o.id is null or o.state<>'payment_pending'or not boss_private.discount_revision_active(r.id)or not boss_private.discount_feature(o.organization_id,'membership_sales')
 or not boss_private.discount_feature(o.organization_id,'discount_membership')or o.total_minor<>(select sum(price_minor)from public.discount_order_items where order_id=o.id)
 or o.base_source_id is not null and not boss_private.discount_source_valid(o.base_source_id)
 or o.campaign_id is not null and not exists(select 1 from public.fundraising_campaigns c where c.id=o.campaign_id and boss_private.fundraising_active(c))
 or o.fundraiser_id is not null and not exists(select 1 from public.fundraising_fundraisers f where f.id=o.fundraiser_id and boss_private.fundraising_member(f))then raise exception'Product eligibility ended'using errcode='PT409';end if;
 if o.subject_id is not null and not boss_private.discount_subject(o.buyer_person_id,o.subject_type,o.subject_id,true)then raise exception'Product subject authority ended'using errcode='PT403';end if;
 return jsonb_build_object('order_id',o.id,'product_revision_id',o.revision_id,'subject_type',o.subject_type,'subject_id',o.subject_id,'base_source_id',o.base_source_id,
 'items',(select jsonb_agg(jsonb_build_object('item_id',id,'price_minor',price_minor,'snapshot',snapshot)order by ordinal)from public.discount_order_items where order_id=o.id));
end$$;
create function boss_private.discount_order_canceled(checkout uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select not exists(select 1 from public.discount_orders o where o.checkout_id=checkout and o.state='payment_pending'
 and(o.campaign_id is null or exists(select 1 from public.fundraising_campaigns c where c.id=o.campaign_id and c.status in('active','scheduled','completed'))))
$$;
create function boss_private.discount_fulfill(order_uuid uuid)returns void language plpgsql volatile security definer set search_path=''as $$
declare o public.discount_orders;item public.discount_order_items;r public.discount_product_revisions;f public.discount_fulfillments;c public.discount_physical_cards;
 member uuid;source uuid;starts timestamptz;ends timestamptz;begin
 select *into o from public.discount_orders where id=order_uuid for update;
 if o.payment_id is null or o.state in('canceled','refunded','review')or not exists(select 1 from public.external_payment_tenders t join public.payment_checkouts ch on ch.id=t.checkout_id
 where t.payment_id=o.payment_id and ch.id=o.checkout_id and t.purpose='products'and t.original_payment_id is null and ch.state in('completed','partially_refunded'))then raise exception'Canonical successful product payment required'using errcode='PT409';end if;
 select received_at into starts from public.payments where id=o.payment_id;
 for item in select *from public.discount_order_items where order_id=o.id order by ordinal for update loop
 if exists(select 1 from public.discount_order_history where item_id=item.id and kind in('refunded','chargeback'))then continue;end if;
 select *into r from public.discount_product_revisions where id=item.revision_id;
 if item.kind='physical'then
 select *into f from public.discount_fulfillments where item_id=item.id for update;
 if f.id is not null and f.state<>'awaiting_inventory'then continue;end if;
 select pc.*into c from public.discount_physical_cards pc join public.discount_card_batches cb on cb.id=pc.batch_id
 where cb.revision_id=r.id and pc.organization_id=o.organization_id and pc.state in('inventory','assigned')and pc.order_item_id is null and pc.claimed_by is null
 and(cb.campaign_id is null or cb.campaign_id=o.campaign_id)and(pc.campaign_id is null or pc.campaign_id=o.campaign_id)
 and(pc.fundraiser_id is null or pc.fundraiser_id=o.fundraiser_id)and cb.status<>'archived'order by pc.id limit 1 for update of pc skip locked;
 if c.id is not null then update public.discount_physical_cards set state='sold',order_item_id=item.id,sold_at=starts,campaign_id=o.campaign_id,fundraiser_id=o.fundraiser_id,updated_at=clock_timestamp(),version=version+1 where id=c.id;
 insert into public.discount_card_history(card_id,action,source_id,organization_id,campaign_id,fundraiser_id)values(c.id,'allocated',item.id,o.organization_id,o.campaign_id,o.fundraiser_id);end if;
 insert into public.discount_fulfillments(item_id,card_id,state)values(item.id,c.id,case when c.id is null then'awaiting_inventory'else'allocated'end)
 on conflict(item_id)do update set card_id=excluded.card_id,state=excluded.state,updated_at=clock_timestamp(),version=discount_fulfillments.version+1 returning *into f;
 insert into public.discount_fulfillment_history(fulfillment_id,state)values(f.id,f.state);
 else
 if item.source_id is not null then continue;end if;
 if item.kind in('state_upgrade','nationwide_upgrade')then
 select ends_at into ends from public.discount_member_sources where id=o.base_source_id;
 if ends<=starts or exists(select 1 from public.discount_source_revocations where source_id=o.base_source_id)then
 update public.discount_orders set state='review'where id=o.id;insert into public.discount_order_history(order_id,item_id,kind,source_key)values(o.id,item.id,'review','review:'||item.id)on conflict do nothing;continue;end if;
 else ends:=starts+make_interval(days=>r.term_days);end if;
 member:=boss_private.discount_issue(r.id,case when item.kind in('state_upgrade','nationwide_upgrade')then'tier_upgrade'when o.channel='fundraising'then'fundraising_product_sale'else'direct_purchase'end,
 'order-item:'||item.id,o.organization_id,o.campaign_id,o.fundraiser_id,null,null,null,o.subject_id,starts,ends,o.base_source_id);
 select id into source from public.discount_member_sources where source_key='order-item:'||item.id;
 update public.discount_order_items set source_id=source where id=item.id;
 insert into public.discount_order_history(order_id,item_id,kind,source_key)values(o.id,item.id,'fulfilled','fulfill:'||item.id)on conflict do nothing;
 end if;
 if o.campaign_id is not null then insert into public.discount_product_credits(item_id,payment_id,campaign_id,fundraiser_id,amount_minor,source_key)
 values(item.id,o.payment_id,o.campaign_id,o.fundraiser_id,item.organization_credit_minor,'sale:'||item.id)on conflict do nothing;end if;
 end loop;
 update public.discount_orders set state=case when state='review'then state when exists(select 1 from public.discount_fulfillments ff join public.discount_order_items ii on ii.id=ff.item_id
 where ii.order_id=o.id and ff.state not in('delivered','canceled'))then'fulfillment_pending'else'fulfilled'end,updated_at=clock_timestamp()where id=o.id;
end$$;
create function boss_private.discount_product_success()returns trigger language plpgsql volatile security definer set search_path=''as $$declare o public.discount_orders;begin
 if new.original_payment_id is null and new.purpose='unallocated'and exists(select 1 from public.payment_checkouts where id=new.checkout_id and purpose='products')then
 select *into o from public.discount_orders where checkout_id=new.checkout_id for update;
 update public.discount_orders set payment_id=new.payment_id,state='review',updated_at=clock_timestamp()where id=o.id;
 insert into public.discount_order_history(order_id,kind,source_key)values(o.id,'review','unallocated:'||new.payment_id)on conflict do nothing;
 elsif new.purpose='products'and new.original_payment_id is null then
 select *into o from public.discount_orders where checkout_id=new.checkout_id for update;
 if o.id is null then raise exception'Product order lineage required'using errcode='23514';end if;
 update public.discount_orders set payment_id=new.payment_id,state='paid',updated_at=clock_timestamp()where id=o.id;
 insert into public.discount_order_history(order_id,kind,source_key)values(o.id,'paid','paid:'||new.payment_id)on conflict do nothing;
 perform boss_private.discount_fulfill(o.id);end if;return new;
end$$;
create trigger discount_product_payment_success after insert on public.external_payment_tenders for each row execute function boss_private.discount_product_success();
create function boss_private.discount_refund_prepare(actor uuid,p_command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb:=p_command->'input';o public.discount_orders;t public.discount_order_items;items jsonb;amount bigint:=0;result jsonb;refund uuid;begin
 perform boss_private.athlete_input(i,array['order_id','item_ids','reason'],array['order_id','item_ids','reason']);
 select *into o from public.discount_orders where id=(i->>'order_id')::uuid;
 if o.payment_id is null or not boss_private.discount_role(actor,'boss_bucks.membership_manage',o.organization_id)then raise exception'Product refund denied'using errcode='PT403';end if;
 perform boss_private.rails_checkout_fence(o.checkout_id);select *into o from public.discount_orders where id=o.id for update;
 if jsonb_typeof(i->'item_ids')is distinct from'array'or jsonb_array_length(i->'item_ids')not between 1 and 100
 or(select count(distinct value)from jsonb_array_elements_text(i->'item_ids'))<>jsonb_array_length(i->'item_ids')then raise exception'Exact distinct original items required'using errcode='PT422';end if;
 select id into refund from public.payment_refund_requests where request_id=(p_command->>'request_id')::uuid;
 for t in select *from public.discount_order_items where id in(select value::uuid from jsonb_array_elements_text(i->'item_ids'))order by id for update loop
 if t.order_id<>o.id or exists(select 1 from public.discount_order_history where item_id=t.id and kind in('refunded','chargeback'))
 or exists(select 1 from public.discount_refund_items ri join public.payment_refund_requests r on r.id=ri.refund_id join public.provider_operations op on op.id=r.operation_id
 where ri.item_id=t.id and op.state not in('failed','voided')and ri.refund_id is distinct from refund)then raise exception'Original item is already corrected or reserved'using errcode='PT409';end if;
 amount:=amount+t.price_minor;end loop;
 if(select count(*)from public.discount_order_items where order_id=o.id and id in(select value::uuid from jsonb_array_elements_text(i->'item_ids')))<>jsonb_array_length(i->'item_ids')then raise exception'Exact order item scope required'using errcode='PT403';end if;
 result:=boss_private.rails_refund_prepare(actor,jsonb_build_object('request_id',p_command->>'request_id','action','refund.prepare','input',jsonb_build_object('payment_id',o.payment_id,'amount_minor',amount,'principal_minor',amount,'allocations','[]'::jsonb,'reason',i->>'reason')));
 refund:=(result->>'refund_id')::uuid;
 insert into public.discount_refund_items(refund_id,item_id)select refund,value::uuid from jsonb_array_elements_text(i->'item_ids')on conflict do nothing;
 return result;
end$$;
create function boss_private.discount_product_correction()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare o public.discount_orders;i public.discount_order_items;card public.discount_physical_cards;unallocated boolean;amount bigint;begin
 select *into o from public.discount_orders where payment_id=new.original_payment_id for update;if o.id is null then return new;end if;
 for i in select oi.*from public.discount_order_items oi where oi.order_id=o.id and(new.refund_request_id is null or exists(select 1 from public.discount_refund_items ri where ri.refund_id=new.refund_request_id and ri.item_id=oi.id))order by oi.id for update loop
 if new.refund_request_id is null and new.principal_minor<o.total_minor then raise exception'Exact original item mapping required'using errcode='PT409';end if;
 if exists(select 1 from public.discount_order_history where item_id=i.id and kind in('refunded','chargeback'))then continue;end if;
 if i.source_id is not null then perform boss_private.discount_revoke(i.source_id,case when new.kind in('chargeback','ach_return')then'chargeback'else'refund'end,new.event_id);end if;
 for card in select *from public.discount_physical_cards where order_item_id=i.id order by id for update loop
 -- A claimed/shipped credential is never silently recycled. Unclaimed,
 -- unshipped inventory may return only through the exact original item.
 unallocated:=card.claimed_at is null and not exists(select 1 from public.discount_fulfillments where item_id=i.id and state in('shipped','delivered'));
 update public.discount_physical_cards set state=case when unallocated then'inventory'when replaced_by is not null then'replaced'else'void'end,order_item_id=case when unallocated then null else order_item_id end,
 sold_at=case when unallocated then null else sold_at end,updated_at=clock_timestamp(),version=version+1 where id=card.id;
 if not unallocated then update boss_private.discount_card_secrets set revoked_at=clock_timestamp()where card_id=card.id;
 perform boss_private.discount_revoke(s.id,'refund',new.event_id)from public.discount_member_sources s where s.source_key='card-trial:'||card.id;
 with recursive descendants as(select id,replaced_by from public.discount_physical_cards where id=card.replaced_by union all select c.id,c.replaced_by from public.discount_physical_cards c join descendants d on c.id=d.replaced_by)
 update public.discount_physical_cards c set state=case when c.replaced_by is null then'void'else'replaced'end,updated_at=clock_timestamp(),version=version+1 where c.id in(select id from descendants);
 with recursive descendants as(select id,replaced_by from public.discount_physical_cards where id=card.replaced_by union all select c.id,c.replaced_by from public.discount_physical_cards c join descendants d on c.id=d.replaced_by)
 update boss_private.discount_card_secrets set revoked_at=clock_timestamp()where card_id in(select id from descendants);end if;
 end loop;
 update public.discount_fulfillments set state='canceled',updated_at=clock_timestamp(),version=version+1 where item_id=i.id;
 insert into public.discount_order_history(order_id,item_id,kind,source_key,source_event_id)values(o.id,i.id,case when new.kind in('chargeback','ach_return')then'chargeback'else'refunded'end,'correction:'||new.event_id||':'||i.id,new.event_id);
 if o.campaign_id is not null then select greatest(0,coalesce(sum(amount_minor),0))into amount from public.discount_product_credits where item_id=i.id;
 insert into public.discount_product_credits(item_id,payment_id,campaign_id,fundraiser_id,amount_minor,source_key,source_event_id)
 values(i.id,o.payment_id,o.campaign_id,o.fundraiser_id,-amount,'correction:'||new.event_id||':'||i.id,new.event_id)on conflict do nothing;end if;
 end loop;
 update public.discount_orders set state=case when state='review'then state when exists(select 1 from public.discount_order_items oi where oi.order_id=o.id and not exists(select 1 from public.discount_order_history h where h.item_id=oi.id and h.kind in('refunded','chargeback')))then'partially_refunded'else'refunded'end,updated_at=clock_timestamp()where id=o.id;
 perform boss_private.discount_audit(null,o.organization_id,null,'product.order.corrected',o.id,null,jsonb_build_object('provider_event_id',new.event_id,'kind',new.kind));return new;
end$$;
create trigger discount_product_payment_correction after insert on public.external_payment_corrections for each row execute function boss_private.discount_product_correction();

-- Unsolicited partial corrections do not identify original items. Preserve
-- evidence at the existing payment review boundary rather than guessing a split.
create function boss_private.discount_product_review(payment uuid,event uuid)returns void language plpgsql volatile security definer set search_path=''as $$
declare o public.discount_orders;begin
 select *into o from public.discount_orders where payment_id=payment for update;
 if o.id is null then raise exception'Original product order required'using errcode='PT404';end if;
 update public.discount_orders set state='review',updated_at=clock_timestamp()where id=o.id;
 update public.payment_checkouts set state='review_required'where id=o.checkout_id;
 insert into public.payment_review_cases(checkout_id,event_id,reason)values(o.checkout_id,event,'contradictory_status')on conflict do nothing;
 update public.settlement_requests sr set state='review'where sr.state='requested'and exists(select 1 from public.settlement_request_items ri where ri.request_id=sr.id and ri.payment_id=payment);
 insert into public.settlement_request_history(request_id,state)select sr.id,'review'from public.settlement_requests sr where sr.state='review'and exists(select 1 from public.settlement_request_items ri where ri.request_id=sr.id and ri.payment_id=payment)and not exists(select 1 from public.settlement_request_history h where h.request_id=sr.id and h.state='review');
 insert into public.discount_order_history(order_id,kind,source_key,source_event_id)values(o.id,'review','ambiguous-correction:'||event,event)on conflict do nothing;
 perform boss_private.discount_rebuild(ds.membership_id)from public.discount_member_sources ds join public.discount_order_items oi on oi.source_id=ds.id where oi.order_id=o.id;
 perform boss_private.discount_audit(null,o.organization_id,null,'product.correction.review',o.id,null,jsonb_build_object('provider_event_id',event,'reason','original_items_required'));
end$$;

-- Guarded source substitutions preserve the shared rails' dispatch, frozen
-- eligibility, unknown/ACH holds, normalized evidence and reconciliation code.
do $$declare d text;needle text;begin
 d:=pg_get_functiondef('boss_private.rails_dispatch(uuid)'::regprocedure);
 needle:='else'||chr(10)||' if not exists(select 1 from public.checkout_charge_allocations';
 if position(needle in d)=0 then raise exception'Phase 7D dispatch checkpoint mismatch';end if;
 d:=replace(d,needle,'elsif c.purpose=''products''then perform boss_private.discount_order_dispatch(c.id);'||chr(10)||needle);
 d:=replace(d,'''share_id'',x.share_id,''attribution'',x.provenance','''product_order'',case when c.purpose=''products''then boss_private.discount_order_dispatch(c.id)end,''share_id'',x.share_id,''attribution'',x.provenance');execute d;
 d:=pg_get_functiondef('boss_private.rails_complete(uuid,uuid)'::regprocedure);
 needle:='else'||chr(10)||' for a in select *from public.checkout_charge_allocations';
 if position(needle in d)=0 then raise exception'Phase 7D completion checkpoint mismatch';end if;
 d:=replace(d,needle,'elsif c.purpose=''products''then if boss_private.discount_order_canceled(c.id)then why:=coalesce(why,''late_success'');end if;'||chr(10)||needle);
 needle:='received_at,source_reference,fundraising_intent_id)';
 if position(needle in d)=0 then raise exception'Product canonical payment checkpoint mismatch';end if;
 d:=replace(d,needle,'received_at,source_reference,fundraising_intent_id,product_order_id)');
 needle:='e.occurred_at,e.transaction_reference,c.intent_id)returning id into payment;';
 if position(needle in d)=0 then raise exception'Product payer lineage checkpoint mismatch';end if;
 d:=replace(d,needle,'e.occurred_at,e.transaction_reference,c.intent_id,(select doo.id from public.discount_orders doo where doo.checkout_id=c.id))returning id into payment;');execute d;
 d:=pg_get_functiondef('boss_private.rails_external_payment_proof()'::regprocedure);
 needle:='and p.payer_person_id is not distinct from c.actor_person_id';
 if position(needle in d)=0 then raise exception'Product original payer proof checkpoint mismatch';end if;
 d:=replace(d,needle,'and p.product_order_id is not distinct from(select doo.id from public.discount_orders doo where doo.checkout_id=c.id) '||needle);
 needle:='or original.status<>''recorded''';
 if position(needle in d)=0 then raise exception'Product correction payer proof checkpoint mismatch';end if;
 d:=replace(d,needle,'or p.product_order_id is distinct from original.product_order_id '||needle);
 needle:='c.state in(''completed'',''partially_refunded'',''refunded'')and et.purpose=c.purpose';
 if position(needle in d)=0 then raise exception'Product review proof checkpoint mismatch';end if;
 d:=replace(d,needle,'(c.state in(''completed'',''partially_refunded'',''refunded'')or c.state=''review_required''and c.purpose=''products''and exists(select 1 from public.discount_orders doo where doo.id=p.product_order_id and doo.state=''review''and exists(select 1 from public.payment_review_cases pr where pr.checkout_id=c.id)))and et.purpose=c.purpose');


 needle:='(c.purpose=''fees''or exists(select 1 from public.fundraising_success_evidence';
 if position(needle in d)=0 then raise exception'Phase 7D external proof checkpoint mismatch';end if;
 d:=replace(d,needle,'(c.purpose=''fees''or c.purpose=''products''and exists(select 1 from public.discount_orders doo where doo.checkout_id=c.id and doo.payment_id=p.id and doo.total_minor=c.principal_minor and cm.snapshot->''product_order''->>''order_id''=doo.id::text)or exists(select 1 from public.fundraising_success_evidence');execute d;
 foreach needle in array array['boss_private.rails_refund_prepare(uuid,jsonb)','boss_private.rails_external_correct(uuid,uuid,text,bigint,jsonb,uuid)']loop
 d:=pg_get_functiondef(needle::regprocedure);d:=replace(d,'c.purpose=''fundraising''and','c.purpose in(''fundraising'',''products'')and');execute d;end loop;
 d:=pg_get_functiondef('boss_private.rails_settlement_match(uuid,uuid,bigint)'::regprocedure);
 needle:='if p.id is null or s.purpose=''unallocated''then';
 if position(needle in d)=0 then raise exception'Phase 7D settlement review checkpoint mismatch';end if;
 d:=replace(d,needle,'if s.purpose=''products''and exists(select 1 from public.discount_orders where payment_id=payment and state=''review'')then return jsonb_build_object(''state'',''held'',''reason'',''original_items_review_required'');end if;'||needle);
 needle:='platformshare:=net_gross-orgshare-cost;';
 if position(needle in d)=0 then raise exception'Phase 7D settlement checkpoint mismatch';end if;
 d:=replace(d,needle,'if s.purpose=''products''then select coalesce(sum(oi.organization_credit_minor),0),coalesce(sum(oi.product_cost_minor),0)into orgshare,cost from public.discount_order_items oi join public.discount_orders doo on doo.id=oi.order_id where doo.payment_id=payment and not exists(select 1 from public.discount_order_history h where h.item_id=oi.id and h.kind in(''refunded'',''chargeback''));end if;'||needle);execute d;
 d:=pg_get_functiondef('boss_private.rails_external_correct(uuid,uuid,text,bigint,jsonb,uuid)'::regprocedure);
 needle:='insert into public.payments(organization_id,method,amount_minor,currency,payer_person_id,recorded_by_person_id,received_at,status,reversal_of_id,fundraising_intent_id,source_reference)';
 if position(needle in d)=0 then raise exception'Phase 7D correction insertion checkpoint mismatch';end if;
 d:=replace(d,needle,'if c.purpose=''products''and r.id is null and principal<c.principal_minor-(select coalesce(sum(ec.principal_minor),0)from public.external_payment_corrections ec where original_payment_id=p.id)then perform boss_private.discount_product_review(p.id,e.id);return null;end if;'||needle);
 d:=replace(d,'reversal_of_id,fundraising_intent_id,source_reference)','reversal_of_id,fundraising_intent_id,source_reference,product_order_id)');
 needle:='p.id,p.fundraising_intent_id,e.event_reference)returning id into reversal;';
 if position(needle in d)=0 then raise exception'Product refund payer lineage checkpoint mismatch';end if;
 d:=replace(d,needle,'p.id,p.fundraising_intent_id,e.event_reference,p.product_order_id)returning id into reversal;');

 needle:='rest:=e.amount_minor-share-cost;';
 if position(needle in d)=0 then raise exception'Phase 7D correction economics checkpoint mismatch';end if;
 d:=replace(d,needle,'if c.purpose=''products''and r.id is not null then select coalesce(sum(oi.organization_credit_minor),0),coalesce(sum(oi.product_cost_minor),0)into share,cost from public.discount_refund_items ri join public.discount_order_items oi on oi.id=ri.item_id where ri.refund_id=r.id;end if;'||needle);execute d;
end$$;
alter function boss_private.fundraising_raised(uuid,uuid,uuid,uuid)rename to fundraising_raised_phase7d;
create function boss_private.fundraising_raised(campaign uuid,fundraiser uuid default null,team uuid default null,unit uuid default null)returns bigint language sql volatile security definer set search_path=''as $$
 select boss_private.fundraising_raised_phase7d(campaign,fundraiser,team,unit)+coalesce((select sum(c.amount_minor)from public.discount_product_credits c
 join public.discount_order_items i on i.id=c.item_id join public.discount_orders o on o.id=i.order_id and o.state<>'review'where c.campaign_id=campaign and(fundraiser is null or c.fundraiser_id=fundraiser)
 and(team is null or i.snapshot->>'team_id'=team::text)and(unit is null or i.snapshot->>'unit_id'=unit::text)),0)::bigint
$$;
alter function boss_private.rails_source_payable(uuid)rename to rails_source_payable_phase7d;
create function boss_private.rails_source_payable(payment uuid)returns bigint language sql volatile security definer set search_path=''as $$
 select case when exists(select 1 from public.discount_orders where payment_id=payment and state='review')then 0 else boss_private.rails_source_payable_phase7d(payment)end
$$;
revoke all on function boss_private.rails_source_payable(uuid),boss_private.rails_source_payable_phase7d(uuid)from public,anon,authenticated,service_role,boss_payment_worker;
do $$declare t text;p record;begin
foreach t in array array['discount_orders','discount_order_items','discount_order_history','discount_fulfillments','discount_fulfillment_history','discount_product_credits','discount_refund_items']loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);end loop;
alter table boss_private.discount_delivery_contacts enable row level security;revoke all on boss_private.discount_delivery_contacts from public,anon,authenticated,service_role,boss_payment_worker;
for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and(proname like'discount_%'or proname='fundraising_raised_phase7d')loop execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;
