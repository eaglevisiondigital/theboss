-- Pending guest trials have a canonical donor lineage, not a guessed Boss person.
create table boss_private.discount_trial_flows(
 id uuid primary key default gen_random_uuid(),request_id uuid not null unique,command_digest text not null,
 claim_id uuid not null unique references boss_private.discount_claims(id),membership_id uuid not null references public.discount_memberships(id),
 donor_id uuid not null references public.fundraising_donors(id),campaign_id uuid not null references public.fundraising_campaigns(id),
 fundraiser_id uuid references public.fundraising_fundraisers(id),intent_id uuid unique references public.fundraising_intents(id),
 expires_at timestamptz not null,created_at timestamptz not null default clock_timestamp());
create index discount_trial_flow_member_idx on boss_private.discount_trial_flows(membership_id);
create index discount_trial_flow_donor_idx on boss_private.discount_trial_flows(donor_id);
create index discount_trial_flow_campaign_idx on boss_private.discount_trial_flows(campaign_id,fundraiser_id);
create index discount_trial_flow_fundraiser_idx on boss_private.discount_trial_flows(fundraiser_id);
alter table boss_private.discount_trial_flows enable row level security;
revoke all on boss_private.discount_trial_flows from public,anon,authenticated,service_role,boss_payment_worker;
create function boss_private.discount_guest_trial(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb;ctx jsonb;c public.fundraising_campaigns;r public.discount_product_revisions;flow boss_private.discount_trial_flows;
 donor uuid;member uuid;claim jsonb;request uuid;h text;begin
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);i:=command->'input';request:=(command->>'request_id')::uuid;
 perform boss_private.athlete_input(i,array['path','revision_id','display_name','email'],array['path','revision_id','display_name']);
 if command->>'action'<>'trial.start'or length(btrim(i->>'display_name'))not between 1 and 100 then raise exception'Invalid trial request'using errcode='PT422';end if;
 ctx:=boss_private.fundraising_public_context(i->>'path');select *into c from public.fundraising_campaigns where id=(ctx->>'campaign_id')::uuid for update;
 h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');perform pg_advisory_xact_lock(hashtextextended('boss-guest-trial:'||request,0));
 select *into flow from boss_private.discount_trial_flows where request_id=request;
 if flow.id is not null then if flow.command_digest<>h then raise exception'Trial request conflict'using errcode='PT409';end if;
 return jsonb_build_object('state','pending_claim','claim_id',flow.claim_id,'replayed',true,'one_time_claim_unavailable',true);end if;
 perform boss_private.discount_fence(null,c.organization_id);
 select *into r from public.discount_product_revisions where id=(i->>'revision_id')::uuid for share;
 if r.id is null or not r.trial_enabled or not boss_private.discount_revision_active(r.id)or not boss_private.discount_feature(c.organization_id,'membership_trials')
 or not boss_private.discount_feature(c.organization_id,'discount_membership')or not exists(select 1 from public.discount_campaign_products b where b.campaign_id=c.id and b.revision_id=r.id
 and b.trial_enabled and b.status='active'and b.starts_at<=clock_timestamp()and(b.ends_at is null or b.ends_at>clock_timestamp()))then raise exception'Trial unavailable'using errcode='PT409';end if;
 perform boss_private.rails_rate('trial:'||c.id,120);
 insert into public.fundraising_donors(display_name,email)values(btrim(i->>'display_name'),nullif(btrim(i->>'email'),''))returning id into donor;
 member:=boss_private.discount_issue(r.id,'fundraising_trial','guest-trial:'||request,c.organization_id,c.id,(ctx->>'fundraiser_id')::uuid,donor,null,null,null,clock_timestamp(),clock_timestamp()+make_interval(days=>r.trial_days));
 claim:=boss_private.discount_claim_issue(member);
 insert into boss_private.discount_trial_flows(request_id,command_digest,claim_id,membership_id,donor_id,campaign_id,fundraiser_id,expires_at)
 values(request,h,(claim->>'claim_id')::uuid,member,donor,c.id,(ctx->>'fundraiser_id')::uuid,(claim->>'expires_at')::timestamptz);
 return (claim-'claim_id')||jsonb_build_object('state','pending_claim','trial_days',r.trial_days,'replayed',false);
end$$;
create function boss_private.discount_trial_donor(input jsonb)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare ctx jsonb;flow boss_private.discount_trial_flows;begin
 if not input?'trial_capability'then return null;end if;
 if coalesce(input->>'trial_capability','')!~'^[a-f0-9]{64}$'then raise exception'Trial continuation unavailable'using errcode='PT404';end if;
 ctx:=boss_private.fundraising_public_context(input->>'path');
 select f.*into flow from boss_private.discount_trial_flows f join boss_private.discount_claims c on c.id=f.claim_id
 where c.digest=encode(sha256(convert_to(input->>'trial_capability','UTF8')),'hex')and c.revoked_at is null and f.expires_at>clock_timestamp()and f.intent_id is null
 and f.campaign_id=(ctx->>'campaign_id')::uuid and f.fundraiser_id is not distinct from(ctx->>'fundraiser_id')::uuid for update of f;
 if flow.id is null then raise exception'Trial continuation unavailable'using errcode='PT404';end if;return flow.donor_id;
end$$;
create function boss_private.discount_trial_flow_id(input jsonb)returns uuid language sql volatile security definer set search_path=''as $$
 select f.id from boss_private.discount_trial_flows f join boss_private.discount_claims c on c.id=f.claim_id where c.digest=encode(sha256(convert_to(input->>'trial_capability','UTF8')),'hex')
 and f.donor_id=boss_private.discount_trial_donor(input)
$$;
create function boss_private.discount_trial_link(input jsonb,intent uuid)returns void language plpgsql volatile security definer set search_path=''as $$declare donor uuid;begin
 if input?'trial_capability'then donor:=boss_private.discount_trial_donor(input);
 update boss_private.discount_trial_flows set intent_id=intent where id=boss_private.discount_trial_flow_id(input);
 end if;
end$$;
do $$declare d text;needle text;begin
 d:=pg_get_functiondef('boss_private.fundraising_guest(jsonb)'::regprocedure);
 needle:='''amount_minor'',''source'']';if position(needle in d)=0 then raise exception'Fundraising input checkpoint mismatch';end if;
 d:=replace(d,needle,'''amount_minor'',''source'',''trial_capability'']');
 needle:='insert into public.fundraising_donors(display_name,email,mobile)values';
 if position(needle in d)=0 then raise exception'Fundraising donor checkpoint mismatch';end if;
 d:=replace(d,needle,'donor:=boss_private.discount_trial_donor(i);if donor is null then '||needle);
 d:=replace(d,'returning id into donor;'||chr(10)||' insert into public.fundraising_intents','returning id into donor;end if;'||chr(10)||' insert into public.fundraising_intents');
 d:=replace(d,'''restricted_use_organization_id'',org,','''restricted_use_organization_id'',org,''trial_flow_id'',case when i?''trial_capability''then boss_private.discount_trial_flow_id(i)end,');
 needle:='returning id into intent;';if position(needle in d)=0 then raise exception'Fundraising intent checkpoint mismatch';end if;
 d:=replace(d,needle,needle||'perform boss_private.discount_trial_link(i,intent);');execute d;
 d:=pg_get_functiondef('boss_private.discount_snapshot_intent()'::regprocedure);
 d:=replace(d,'insert into public.discount_intent_product_snapshots(intent_id,binding_id,revision_id)values(new.id,b.id,b.revision_id)',
 'insert into public.discount_intent_product_snapshots(intent_id,binding_id,revision_id,trial_membership_id)values(new.id,b.id,b.revision_id,(select f.membership_id from boss_private.discount_trial_flows f where f.id=(new.provenance->>''trial_flow_id'')::uuid and f.donor_id=new.donor_id and f.campaign_id=new.campaign_id))');execute d;
end$$;
create function boss_private.discount_catalog(org uuid,path text default null)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare ctx jsonb;campaign uuid;begin
 if path is not null then ctx:=boss_private.fundraising_public_context(path);campaign:=(ctx->>'campaign_id')::uuid;
 select organization_id into org from public.fundraising_campaigns where id=campaign;end if;
 if org is null or not boss_private.discount_feature(org,'discount_membership')then return '[]';end if;
 return coalesce((select jsonb_agg(row)from(select jsonb_build_object('revision_id',r.id,'organization_id',org,'product_id',p.id,'membership_product_id',r.membership_product_id,'name',p.name,'kind',p.kind,'fulfillment_type',r.fulfillment_type,
 'price_minor',r.price_minor,'currency',r.currency,'tier',r.tier,'country',r.country,'region',r.region,'market',r.market,'subject_type',r.subject_type,
 'term_days',r.term_days,'upgrade_from_tiers',r.upgrade_from_tiers,'trial_days',r.trial_days,'trial_enabled',r.trial_enabled and coalesce(b.trial_enabled,false)and boss_private.discount_feature(org,'membership_trials'),
 'gift_enabled',r.gift_enabled and coalesce(b.gift_enabled,false),'gift_threshold_copy','More than $25 (at least $25.01 in USD)',
 'sale_enabled',case when campaign is null then'direct'=any(r.sale_channels)else coalesce(b.sale_enabled,false)and'fundraising'=any(r.sale_channels)end,
 'payment_available',exists(select 1 from public.payment_routing_revisions rr where rr.organization_id=org and rr.purpose='products'and rr.currency=r.currency
 and boss_private.rails_route_current(rr.id)and(rr.scope_type='organization'and rr.scope_id=org or campaign is not null and rr.scope_type='campaign'and rr.scope_id=campaign)and boss_private.rails_account_ready(rr.account_id,org,'card',r.currency))
 and boss_private.rails_feature(org,'online_payments')and boss_private.discount_feature(org,'membership_sales'))row
 from public.discount_product_revisions r join public.discount_products p on p.id=r.product_id
 left join lateral(select *from public.discount_campaign_products where campaign_id=campaign and revision_id=r.id and status='active'and starts_at<=clock_timestamp()
 and(ends_at is null or ends_at>clock_timestamp())order by created_at desc,id desc limit 1)b on true
 where(r.organization_id=org or r.organization_id is null)and boss_private.discount_revision_active(r.id)
 and(case when campaign is null then'direct'=any(r.sale_channels)or p.kind in('state_upgrade','nationwide_upgrade')else b.id is not null end)
 order by p.code,r.revision desc limit 50)q),'[]');
end$$;
create function boss_private.discount_read(query jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;mode text;org uuid;member uuid;before uuid;fundraiser public.fundraising_fundraisers;financial boolean;inventory boolean;fulfillment boolean;result jsonb;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();if actor is null then raise exception'Authentication required'using errcode='PT401';end if;
 perform boss_private.athlete_input(query,array['mode','organization_id','membership_id','before','path','order_id','fundraiser_id'],array[]::text[]);
 mode:=coalesce(query->>'mode','consumer');org:=(query->>'organization_id')::uuid;member:=(query->>'membership_id')::uuid;before:=(query->>'before')::uuid;
 if mode='consumer'then
 if member is not null and not exists(select 1 from public.discount_memberships m where m.id=member and boss_private.discount_subject(actor,m.subject_type,m.subject_id))then raise exception'Membership access denied'using errcode='PT403';end if;
 return boss_private.bucks_safe_money_json(jsonb_build_object('mode',mode,'catalog',boss_private.discount_catalog(org,query->>'path'),
 'households',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'name',h.name))from public.households h join public.household_memberships hm on hm.household_id=h.id where hm.person_id=actor and hm.is_primary_contact and hm.status='active'and hm.starts_at<=clock_timestamp()and(hm.ends_at is null or hm.ends_at>clock_timestamp())and h.status='active'),'[]'),
 'memberships',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'product_id',m.product_id,'household_id',m.household_id,'display_id',m.display_id,'name',p.name,'subject_type',m.subject_type,
 'display_name',case when m.subject_type='person'then(select display_name from public.people where id=m.subject_id)else(select name from public.households where id=m.subject_id)end,
 'effective',boss_private.discount_effective(m.id),'base_source_id',(select s.id from public.discount_member_sources s where s.membership_id=m.id and s.kind<>'tier_upgrade'and boss_private.discount_source_valid(s.id)order by s.ends_at desc,s.id limit 1),'cards',coalesce((select jsonb_agg(jsonb_build_object('id',id,'serial',serial,'state',state,'valid',boss_private.discount_card_valid(id)))from(select *from public.discount_physical_cards where membership_id=m.id order by id limit 20)c),'[]'),
 'sources',coalesce((select jsonb_agg(jsonb_build_object('kind',s.kind,'tier',s.tier,'starts_at',s.starts_at,'ends_at',s.ends_at,'revoked',exists(select 1 from public.discount_source_revocations v where v.source_id=s.id)))from(select *from public.discount_member_sources where membership_id=m.id order by created_at desc,id limit 30)s),'[]')))
 from(select *from public.discount_memberships m where(member is null or m.id=member)and(before is null or m.id<before)
 and(m.person_id=actor or m.household_id in(select hm.household_id from public.household_memberships hm where hm.person_id=actor and hm.status='active'and hm.starts_at<=clock_timestamp()and(hm.ends_at is null or hm.ends_at>clock_timestamp())))
 and boss_private.discount_subject(actor,m.subject_type,m.subject_id)order by id desc limit 50)m join public.discount_products p on p.id=m.product_id),'[]'),
 'orders',coalesce((select jsonb_agg(jsonb_build_object('id',id,'state',state,'total_minor',total_minor,'currency',currency,'quantity',quantity,'created_at',created_at))from(select *from public.discount_orders where buyer_person_id=actor order by created_at desc,id limit 50)o),'[]')));
 elsif mode='fundraiser'then
 select *into fundraiser from public.fundraising_fundraisers where id=(query->>'fundraiser_id')::uuid;
 org:=fundraiser.organization_id;perform boss_private.discount_fence(actor,org);
 if fundraiser.id is null or not boss_private.discount_feature(org,'discount_membership')or not boss_private.fundraising_module(org,'fundraising')
 or not(boss_private.fundraising_related(actor,fundraiser)or boss_private.fundraising_role(actor,'fundraising.view',org,fundraiser.unit_id,fundraiser.team_id))then raise exception'Exact fundraiser report denied'using errcode='PT403';end if;
 return boss_private.bucks_safe_money_json(jsonb_build_object('mode',mode,'catalog','[]'::jsonb,'fundraiser_report',jsonb_build_object('name',coalesce(fundraiser.public_display_name,'Fundraiser'),'currency',(select currency from public.fundraising_campaigns where id=fundraiser.campaign_id),
 'fundraising_credit_minor',(select coalesce(sum(dc.amount_minor),0)from public.discount_product_credits dc join public.discount_order_items oi on oi.id=dc.item_id join public.discount_orders o on o.id=oi.order_id where dc.fundraiser_id=fundraiser.id and o.state<>'review'),
 'product_sales',coalesce((select jsonb_object_agg(kind,n)from(select oi.kind,count(*)n from public.discount_order_items oi join public.discount_orders o on o.id=oi.order_id where o.fundraiser_id=fundraiser.id and o.payment_id is not null and o.state<>'review'and not exists(select 1 from public.discount_order_history h where h.item_id=oi.id and h.kind in('refunded','chargeback'))group by oi.kind)x),'{}'),
 'inventory',coalesce((select jsonb_object_agg(state,n)from(select state,count(*)n from public.discount_physical_cards where fundraiser_id=fundraiser.id group by state)x),'{}'))));
 elsif mode='organization'then
 perform boss_private.discount_fence(actor,org);
 if not boss_private.discount_feature(org,'discount_membership')or not boss_private.discount_role(actor,'boss_bucks.membership_view',org)then raise exception'Product reporting denied'using errcode='PT403';end if;
 financial:=boss_private.fundraising_role(actor,'fundraising.financial_view',org);inventory:=boss_private.discount_role(actor,'boss_bucks.inventory_manage',org);fulfillment:=boss_private.discount_role(actor,'boss_bucks.fulfillment_manage',org);
 return boss_private.bucks_safe_money_json(jsonb_build_object('mode',mode,'organization_id',org,'can_refund',boss_private.discount_role(actor,'boss_bucks.membership_manage',org)and boss_private.rails_role(actor,'payments.refund',org)and boss_private.rails_feature(org,'refunds'),'can_manage_products',boss_private.discount_platform(actor),'can_inventory',inventory,'can_fulfillment',fulfillment,'can_financial_view',financial,
 'can_manage_campaigns',boss_private.fundraising_role(actor,'fundraising.manage',org),
 'statistics',jsonb_build_object('trials_started',(select count(*)from public.discount_member_sources where organization_id=org and kind in('fundraising_trial','physical_card_digital_trial')),'gift_sources',(select count(*)from public.discount_member_sources where organization_id=org and kind='supporter_gift'),'gift_claimed',(select count(*)from public.discount_member_sources s join public.discount_memberships m on m.id=s.membership_id where s.organization_id=org and s.kind='supporter_gift'and m.subject_id is not null),'fundraising_credits',coalesce((select jsonb_agg(jsonb_build_object('currency',currency,'amount_minor',amount_minor))from(select o.currency,sum(dc.amount_minor)amount_minor from public.discount_product_credits dc join public.discount_order_items oi on oi.id=dc.item_id join public.discount_orders o on o.id=oi.order_id where o.organization_id=org and o.state<>'review'group by o.currency order by o.currency)x),'[]'::jsonb)),
 'financial_statistics',case when financial then coalesce((select jsonb_agg(jsonb_build_object('currency',currency,'digital_sales_minor',digital,'physical_sales_minor',physical,'refunded_products_minor',refunded))from(select o.currency,
 coalesce(sum(oi.price_minor)filter(where oi.kind<>'physical'),0)digital,coalesce(sum(oi.price_minor)filter(where oi.kind='physical'),0)physical,
 coalesce(sum(oi.price_minor)filter(where exists(select 1 from public.discount_order_history h where h.item_id=oi.id and h.kind in('refunded','chargeback'))),0)refunded
 from public.discount_order_items oi join public.discount_orders o on o.id=oi.order_id where o.organization_id=org and o.payment_id is not null and o.state<>'review'group by o.currency order by o.currency)x),'[]')else'[]'::jsonb end,
 'catalog',boss_private.discount_catalog(org),'products',case when boss_private.discount_platform(actor)then coalesce((select jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name,'kind',kind,'status',status))from(select *from public.discount_products order by code limit 100)p),'[]')else'[]'::jsonb end,
 'revisions',case when boss_private.discount_platform(actor)then coalesce((select jsonb_agg(to_jsonb(r)||jsonb_build_object('active',boss_private.discount_revision_active(r.id)))from(select *from public.discount_product_revisions where organization_id=org or organization_id is null order by created_at desc,id limit 100)r),'[]')else'[]'::jsonb end,
 'campaigns',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'status',status))from(select *from public.fundraising_campaigns where organization_id=org and status not in('archived','canceled')order by id limit 50)c),'[]'),
 'fundraisers',case when inventory then coalesce((select jsonb_agg(jsonb_build_object('id',id,'campaign_id',campaign_id,'name',coalesce(public_display_name,'Fundraiser')))from(select *from public.fundraising_fundraisers where organization_id=org and status='active'order by id limit 100)f),'[]')else'[]'::jsonb end,
 'settlement_policies',case when boss_private.discount_platform(actor)then coalesce((select jsonb_agg(jsonb_build_object('id',id,'revision',revision,'currency',currency,'organization_basis_points',organization_basis_points,'platform_basis_points',platform_basis_points,'processor_fee_owner',processor_fee_owner))from(select *from public.settlement_policy_revisions where organization_id=org and purpose='products'order by revision desc limit 30)s),'[]')else'[]'::jsonb end,
 'campaign_products',coalesce((select jsonb_agg(jsonb_build_object('id',id,'campaign_id',campaign_id,'revision_id',revision_id,'trial_enabled',trial_enabled,'gift_enabled',gift_enabled,'sale_enabled',sale_enabled,'status',status))from(select *from public.discount_campaign_products where organization_id=org order by id limit 100)b),'[]'),
 'batches',case when inventory then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'status',b.status,'quantity',b.quantity,'controlled',b.controlled,
 'counts',(select jsonb_object_agg(state,n)from(select state,count(*)n from public.discount_physical_cards where batch_id=b.id group by state)q)))from(select *from public.discount_card_batches where(organization_id=org or organization_id is null and boss_private.discount_platform(actor))and(before is null or id<before)order by id desc limit 50)b),'[]')else'[]'::jsonb end,
 'cards',case when inventory then coalesce((select jsonb_agg(jsonb_build_object('id',id,'batch_id',batch_id,'serial',serial,'state',state,'version',version,'campaign_id',campaign_id,'fundraiser_id',fundraiser_id,'claimed',claimed_at is not null))from(select *from public.discount_physical_cards where(organization_id=org or organization_id is null and boss_private.discount_platform(actor))and(before is null or id<before)order by id desc limit 100)c),'[]')else'[]'::jsonb end,
 'orders',case when financial then coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'state',o.state,'total_minor',o.total_minor,'currency',o.currency,'quantity',o.quantity,'campaign_id',o.campaign_id,'fundraiser_id',o.fundraiser_id,'items',case when o.id=(query->>'order_id')::uuid then coalesce((select jsonb_agg(jsonb_build_object('id',oi.id,'kind',oi.kind,'price_minor',oi.price_minor,'corrected',exists(select 1 from public.discount_order_history h where h.item_id=oi.id and h.kind in('refunded','chargeback'))))from public.discount_order_items oi where oi.order_id=o.id),'[]')else'[]'::jsonb end))from(select *from public.discount_orders where organization_id=org and((query->>'order_id')is null or id=(query->>'order_id')::uuid)and(before is null or id<before)order by id desc limit 100)o),'[]')else'[]'::jsonb end,
 'fulfillments',case when fulfillment then coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'version',f.version,'state',f.state,'card_id',f.card_id,'order_id',o.id,'fulfillment_type',i.fulfillment_type))from public.discount_fulfillments f join public.discount_order_items i on i.id=f.item_id join public.discount_orders o on o.id=i.order_id where o.organization_id=org and(before is null or f.id<before)and f.id in(select ff.id from public.discount_fulfillments ff join public.discount_order_items ii on ii.id=ff.item_id join public.discount_orders oo on oo.id=ii.order_id where oo.organization_id=org and(before is null or ff.id<before)order by ff.id desc limit 100)),'[]')else'[]'::jsonb end));
 elsif mode='delivery'then
 perform boss_private.discount_fence(actor,org);
 if not boss_private.discount_feature(org,'discount_membership')or not boss_private.discount_feature(org,'physical_cards')then raise exception'Delivery scope denied'using errcode='PT403';end if;
 if not exists(select 1 from public.discount_orders o where o.id=(query->>'order_id')::uuid and o.organization_id=org and boss_private.discount_role(actor,'boss_bucks.fulfillment_manage',org))then raise exception'Delivery scope denied'using errcode='PT403';end if;
 return jsonb_build_object('mode',mode,'delivery',(select jsonb_build_object('email',email,'address',address)from boss_private.discount_delivery_contacts where order_id=(query->>'order_id')::uuid));
 else raise exception'Unknown membership view'using errcode='PT422';end if;
end$$;

-- Idempotent receipts never retain authority. Fence and reauthorize every replay.
create function boss_private.discount_replay_authorized(actor uuid,action text,i jsonb,receipt jsonb)returns boolean language plpgsql volatile security definer set search_path=''as $$
declare org uuid;member public.discount_memberships;c public.discount_physical_cards;b public.discount_card_batches;f public.fundraising_fundraisers;o public.discount_orders;begin
 if action in('product.create','revision.create','revision.status','membership.status','maintenance.expire')then
 perform boss_private.discount_fence(actor);return boss_private.discount_platform(actor);end if;
 if action in('membership.claim','card.claim','trial.start','membership.rebuild')then
 select *into member from public.discount_memberships where id=(receipt->>'membership_id')::uuid;
 perform boss_private.discount_fence(actor,null,member.household_id);
 return member.id is not null and boss_private.discount_subject(actor,member.subject_type,member.subject_id,true)
 and exists(select 1 from public.discount_member_sources s where s.membership_id=member.id and boss_private.discount_feature(s.organization_id,'discount_membership'))
 and case when action='card.claim'then exists(select 1 from public.discount_physical_cards pc join boss_private.discount_card_secrets cs on cs.card_id=pc.id
 where pc.serial=i->>'serial'and pc.claimed_by=actor and pc.membership_id=member.id and pc.state='active'and cs.revoked_at is null and boss_private.discount_feature(pc.organization_id,'physical_cards'))
 when action='membership.claim'then exists(select 1 from boss_private.discount_claims cl where cl.digest=encode(sha256(convert_to(i->>'claim_secret','UTF8')),'hex')and cl.claimed_by=actor and cl.membership_id=member.id and cl.revoked_at is null and cl.expires_at>clock_timestamp())else true end;end if;
 if action in('campaign.configure','campaign.end')then
 select organization_id into org from public.fundraising_campaigns where id=coalesce((i->>'campaign_id')::uuid,(select campaign_id from public.discount_campaign_products where id=(i->>'binding_id')::uuid));
 perform boss_private.discount_fence(actor,org);return boss_private.discount_feature(org,'discount_membership')and boss_private.fundraising_role(actor,'fundraising.manage',org);end if;
 if action='source.revoke'then select organization_id into org from public.discount_member_sources where id=(i->>'source_id')::uuid;
 perform boss_private.discount_fence(actor,org);return boss_private.discount_role(actor,'boss_bucks.membership_manage',org);end if;
 if action in('batch.create','batch.archive','card.replace')then
 if action='batch.create'then org:=(i->>'organization_id')::uuid;
 elsif action='batch.archive'then select organization_id into org from public.discount_card_batches where id=(i->>'batch_id')::uuid;
 else select organization_id into org from public.discount_physical_cards where id=(i->>'card_id')::uuid;end if;
 perform boss_private.discount_fence(actor,org);return case when org is null then boss_private.discount_platform(actor)else boss_private.discount_feature(org,'physical_cards')and boss_private.discount_role(actor,'boss_bucks.inventory_manage',org)end;end if;
 if action in('cards.assign','cards.return','cards.print','cards.void')then
 org:=(i->>'organization_id')::uuid;select *into f from public.fundraising_fundraisers where id=(i->>'fundraiser_id')::uuid and campaign_id=(i->>'campaign_id')::uuid and organization_id=org;
 perform boss_private.discount_fence(actor,org);
 return boss_private.discount_feature(org,'physical_cards')and(boss_private.discount_role(actor,'boss_bucks.inventory_manage',org)
 or f.id is not null and boss_private.fundraising_role(actor,'fundraising.manage',org,f.unit_id,f.team_id)
 and not exists(select 1 from jsonb_array_elements_text(i->'card_ids')v left join public.discount_physical_cards pc on pc.id=v.value::uuid
 where pc.id is null or pc.organization_id is distinct from org or pc.campaign_id is distinct from f.campaign_id or pc.fundraiser_id is distinct from f.id));end if;
 if action in('order.create','order.cancel','order.refund','fulfillment.retry','fulfillment.status')then
 select *into o from public.discount_orders where id=coalesce((i->>'order_id')::uuid,(receipt->>'order_id')::uuid,
 (select oi.order_id from public.discount_fulfillments ff join public.discount_order_items oi on oi.id=ff.item_id where ff.id=(i->>'fulfillment_id')::uuid));
 perform boss_private.discount_fence(actor,o.organization_id,o.subject_id);
 if o.id is null or not boss_private.discount_feature(o.organization_id,'discount_membership')then return false;end if;
 if action like'fulfillment.%'then return boss_private.discount_role(actor,'boss_bucks.fulfillment_manage',o.organization_id);end if;
 if action='order.refund'then return boss_private.discount_role(actor,'boss_bucks.membership_manage',o.organization_id)and boss_private.rails_role(actor,'payments.refund',o.organization_id)and boss_private.rails_feature(o.organization_id,'refunds');end if;
 return o.buyer_person_id=actor and boss_private.discount_subject(actor,o.subject_type,o.subject_id,true)
 or action='order.cancel'and boss_private.discount_role(actor,'boss_bucks.membership_manage',o.organization_id);end if;
 return false;
end$$;

create function boss_private.discount_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare actor uuid;action text;i jsonb;request uuid;h text;prior boss_private.discount_requests;result jsonb:='{}';org uuid;id uuid;
 p public.discount_products;r public.discount_product_revisions;m public.discount_memberships;s public.discount_member_sources;b public.discount_campaign_products;
 c public.fundraising_campaigns;o public.discount_orders;f public.discount_fulfillments;ctx jsonb;revision bigint;status text;days integer;source uuid;ent uuid;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();if actor is null then raise exception'Authentication required'using errcode='PT401';end if;
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);
 action:=command->>'action';i:=command->'input';request:=(command->>'request_id')::uuid;h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');
 if jsonb_typeof(i)is distinct from'object'or octet_length(command::text)>256000 then raise exception'Invalid product request'using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-discount-request:'||request,0));
 select *into prior from boss_private.discount_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command_digest<>h or prior.action<>action then raise exception'Product request conflict'using errcode='PT409';end if;
 if not boss_private.discount_replay_authorized(actor,action,i,prior.result)then raise exception'Product request authority ended'using errcode='PT403';end if;
 result:=prior.result;
 if result?'membership_id'then result:=result||jsonb_build_object('effective',boss_private.discount_effective((result->>'membership_id')::uuid));end if;
 return result||jsonb_build_object('action',action,'replayed',true,'one_time_export_unavailable',action='batch.create');end if;
 if action in('membership.claim','card.claim')then perform boss_private.rails_rate('discount-claim:'||actor,30);end if;
 if action='maintenance.expire'then
 perform boss_private.athlete_input(i,array['limit'],array['limit']);perform boss_private.discount_fence(actor);
 if not boss_private.discount_platform(actor)then raise exception'Membership maintenance denied'using errcode='PT403';end if;
 result:=boss_private.discount_expire_batch((i->>'limit')::integer);
 elsif action='product.create'then
 perform boss_private.athlete_input(i,array['code','name','kind'],array['code','name','kind']);perform boss_private.discount_fence(actor);
 if not boss_private.discount_platform(actor)then raise exception'Product management denied'using errcode='PT403';end if;
 insert into public.discount_products(code,name,kind,created_by)values(i->>'code',i->>'name',i->>'kind',actor)returning discount_products.id into id;
 perform boss_private.discount_audit(actor,null,null,'product.created',id,request);result:=jsonb_build_object('product_id',id);
 elsif action='revision.create'then
 perform boss_private.athlete_input(i,array['product_id','membership_product_id','organization_id','subject_type','claim_policy','currency','price_minor','term_days','trial_days','country','region','market','tier','organization_credit_minor','platform_retained_minor','product_cost_minor','settlement_policy_id','sale_channels','upgrade_from_tiers','trial_enabled','gift_enabled','fulfillment_type','validity_anchor','card_validity_days','starts_at','ends_at'],
 array['product_id','membership_product_id','subject_type','claim_policy','currency','price_minor','country','region','market','tier','sale_channels','trial_enabled','gift_enabled','fulfillment_type','starts_at']);
 org:=(i->>'organization_id')::uuid;perform boss_private.discount_fence(actor,org);
 if not boss_private.discount_platform(actor)then raise exception'Product pricing management denied'using errcode='PT403';end if;
 select *into p from public.discount_products where id=(i->>'product_id')::uuid for update;
 if p.id is null or p.status='archived'or not exists(select 1 from public.discount_products where id=(i->>'membership_product_id')::uuid and kind='digital'and status<>'archived')
 or p.kind='digital'and p.id<>(i->>'membership_product_id')::uuid
 or(i->>'gift_enabled')::boolean and p.kind<>'digital'
 or p.kind='digital'and jsonb_array_length(i->'sale_channels')>0 and i->>'term_days'is null
 or p.kind='physical'and(i->>'trial_days'is null or i->>'validity_anchor'is null or i->>'card_validity_days'is null)
 or p.kind='state_upgrade'and i->>'tier'<>'state'or p.kind='nationwide_upgrade'and i->>'tier'<>'nationwide'
 or i->>'settlement_policy_id'is not null and not exists(select 1 from public.settlement_policy_revisions sp where sp.id=(i->>'settlement_policy_id')::uuid and sp.organization_id=org and sp.purpose='products'and sp.currency=i->>'currency')
 then raise exception'Explicit coherent product revision required'using errcode='PT422';end if;
 select coalesce(max(dr.revision),0)+1 into revision from public.discount_product_revisions dr where dr.product_id=p.id;
 insert into public.discount_product_revisions(product_id,revision,organization_id,membership_product_id,subject_type,claim_policy,currency,price_minor,term_days,trial_days,country,region,market,tier,organization_credit_minor,platform_retained_minor,product_cost_minor,settlement_policy_id,sale_channels,upgrade_from_tiers,trial_enabled,gift_enabled,fulfillment_type,validity_anchor,card_validity_days,starts_at,ends_at,created_by)
 values(p.id,revision,org,(i->>'membership_product_id')::uuid,i->>'subject_type',i->>'claim_policy',i->>'currency',(i->>'price_minor')::bigint,(i->>'term_days')::int,(i->>'trial_days')::int,i->>'country',i->>'region',i->>'market',i->>'tier',
 (i->>'organization_credit_minor')::bigint,(i->>'platform_retained_minor')::bigint,(i->>'product_cost_minor')::bigint,(i->>'settlement_policy_id')::uuid,array(select jsonb_array_elements_text(i->'sale_channels')),case when i?'upgrade_from_tiers'then array(select jsonb_array_elements_text(i->'upgrade_from_tiers'))else array['local']end,
 (i->>'trial_enabled')::boolean,(i->>'gift_enabled')::boolean,i->>'fulfillment_type',i->>'validity_anchor',(i->>'card_validity_days')::int,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning discount_product_revisions.id into id;
 result:=jsonb_build_object('revision_id',id,'revision',revision);perform boss_private.discount_audit(actor,org,null,'product.revision.created',id,request);
 elsif action='revision.status'then
 perform boss_private.athlete_input(i,array['revision_id','state'],array['revision_id','state']);perform boss_private.discount_fence(actor);
 if not boss_private.discount_platform(actor)then raise exception'Product activation denied'using errcode='PT403';end if;
 select *into r from public.discount_product_revisions where id=(i->>'revision_id')::uuid for update;
 if r.id is null then raise exception'Revision unavailable'using errcode='PT404';end if;
 insert into public.discount_revision_events(revision_id,state,actor_id)values(r.id,i->>'state',actor);
 if i->>'state'='active'then update public.discount_products set status='active'where id=r.product_id and status<>'archived';end if;
 result:=jsonb_build_object('revision_id',r.id,'state',i->>'state');perform boss_private.discount_audit(actor,r.organization_id,null,'product.revision.'||(i->>'state'),r.id,request);
 elsif action='campaign.configure'then
 perform boss_private.athlete_input(i,array['campaign_id','revision_id','trial_enabled','gift_enabled','sale_enabled','ends_at'],array['campaign_id','revision_id','trial_enabled','gift_enabled','sale_enabled']);
 select *into c from public.fundraising_campaigns where id=(i->>'campaign_id')::uuid for update;org:=c.organization_id;perform boss_private.discount_fence(actor,org);
 if not boss_private.fundraising_role(actor,'fundraising.manage',org)or not boss_private.discount_feature(org,'discount_membership')then raise exception'Campaign product configuration denied'using errcode='PT403';end if;
 select *into r from public.discount_product_revisions where id=(i->>'revision_id')::uuid for share;
 if r.id is null or not boss_private.discount_revision_active(r.id)or r.organization_id is not null and r.organization_id<>org
 or(i->>'trial_enabled')::boolean and not r.trial_enabled or(i->>'gift_enabled')::boolean and not r.gift_enabled
 or(i->>'gift_enabled')::boolean and(c.currency<>'USD'or c.reward_policy->>'currency'is distinct from'USD'or c.reward_policy->>'comparison'is distinct from'gt'or c.reward_policy->>'threshold_minor'is distinct from'2500')
 or(i->>'sale_enabled')::boolean and(not'fundraising'=any(r.sale_channels)or r.currency<>c.currency)
 or(i->>'gift_enabled')::boolean and exists(select 1 from public.discount_campaign_products where campaign_id=c.id and gift_enabled and status='active'and(ends_at is null or ends_at>clock_timestamp()))
 then raise exception'Approved campaign product policy required'using errcode='PT422';end if;
 insert into public.discount_campaign_products(organization_id,campaign_id,revision_id,trial_enabled,gift_enabled,sale_enabled,starts_at,ends_at,created_by)
 values(org,c.id,r.id,(i->>'trial_enabled')::boolean,(i->>'gift_enabled')::boolean,(i->>'sale_enabled')::boolean,clock_timestamp(),(i->>'ends_at')::timestamptz,actor)returning discount_campaign_products.id into id;
 result:=jsonb_build_object('binding_id',id);perform boss_private.discount_audit(actor,org,null,'campaign.product.enabled',id,request);
 elsif action='campaign.end'then
 perform boss_private.athlete_input(i,array['binding_id'],array['binding_id']);select *into b from public.discount_campaign_products where id=(i->>'binding_id')::uuid;
 perform 1 from public.fundraising_campaigns where id=b.campaign_id for update;perform boss_private.discount_fence(actor,b.organization_id);
 if not boss_private.fundraising_role(actor,'fundraising.manage',b.organization_id)then raise exception'Campaign product configuration denied'using errcode='PT403';end if;
 update public.discount_campaign_products set status='ended',ends_at=greatest(starts_at+interval'1 microsecond',clock_timestamp())where id=b.id;
 result:=jsonb_build_object('binding_id',b.id,'state','ended');perform boss_private.discount_audit(actor,b.organization_id,null,'campaign.product.ended',b.id,request);
 elsif action='trial.start'then
 perform boss_private.athlete_input(i,array['revision_id','path','household_id'],array['revision_id','path']);ctx:=boss_private.fundraising_public_context(i->>'path');
 select *into c from public.fundraising_campaigns where id=(ctx->>'campaign_id')::uuid for update;org:=c.organization_id;
 perform boss_private.discount_fence(actor,org,(i->>'household_id')::uuid);select *into r from public.discount_product_revisions where id=(i->>'revision_id')::uuid for share;
 if r.id is null or not boss_private.discount_revision_active(r.id)or not r.trial_enabled or not boss_private.discount_feature(org,'membership_trials')
 or not boss_private.discount_feature(org,'discount_membership')or not exists(select 1 from public.discount_campaign_products b where b.campaign_id=c.id and b.revision_id=r.id and b.trial_enabled and b.status='active'
 and b.starts_at<=clock_timestamp()and(b.ends_at is null or b.ends_at>clock_timestamp()))then raise exception'Trial unavailable'using errcode='PT409';end if;
 id:=case r.subject_type when'person'then actor else(i->>'household_id')::uuid end;
 if not boss_private.discount_subject(actor,r.subject_type,id,true)then raise exception'Trial subject denied'using errcode='PT403';end if;
 id:=boss_private.discount_issue(r.id,'fundraising_trial','trial:'||request,org,c.id,(ctx->>'fundraiser_id')::uuid,null,null,null,id,clock_timestamp(),clock_timestamp()+make_interval(days=>r.trial_days));
 result:=jsonb_build_object('membership_id',id,'effective',boss_private.discount_effective(id));perform boss_private.discount_audit(actor,org,id,'membership.trial.started',id,request);
 elsif action='membership.claim'then
 perform boss_private.athlete_input(i,array['claim_secret','household_id'],array['claim_secret']);id:=boss_private.discount_claim(actor,i->>'claim_secret',(i->>'household_id')::uuid);result:=jsonb_build_object('membership_id',id,'effective',boss_private.discount_effective(id));
 elsif action='membership.rebuild'then
 perform boss_private.athlete_input(i,array['membership_id'],array['membership_id']);select *into m from public.discount_memberships where id=(i->>'membership_id')::uuid;
 perform boss_private.discount_fence(actor,null,m.household_id);
 if not boss_private.discount_subject(actor,m.subject_type,m.subject_id,true)and not boss_private.discount_platform(actor)then raise exception'Membership rebuild denied'using errcode='PT403';end if;
 result:=jsonb_build_object('membership_id',m.id,'effective',boss_private.discount_rebuild(m.id));
 elsif action='membership.status'then
 perform boss_private.athlete_input(i,array['membership_id','state'],array['membership_id','state']);perform boss_private.discount_fence(actor);
 if not boss_private.discount_platform(actor)or i->>'state'not in('suspended','revoked','active')then raise exception'Membership lifecycle denied'using errcode='PT403';end if;
 select *into m from public.discount_memberships where id=(i->>'membership_id')::uuid for update;
 if m.id is null or m.subject_id is null then raise exception'Claimed membership required'using errcode='PT409';end if;
 update public.discount_memberships set state=i->>'state',updated_at=clock_timestamp(),version=version+1 where id=m.id;
 result:=jsonb_build_object('membership_id',m.id,'effective',boss_private.discount_rebuild(m.id));perform boss_private.discount_audit(actor,null,m.id,'membership.'||(i->>'state'),m.id,request);
 elsif action='source.revoke'then
 perform boss_private.athlete_input(i,array['source_id'],array['source_id']);select *into s from public.discount_member_sources where id=(i->>'source_id')::uuid;
 perform boss_private.discount_fence(actor,s.organization_id);
 if s.id is null or not boss_private.discount_role(actor,'boss_bucks.membership_manage',s.organization_id)then raise exception'Membership source scope denied'using errcode='PT403';end if;
 perform boss_private.discount_revoke(s.id,'revoked',null,actor);result:=jsonb_build_object('source_id',s.id);
 elsif action='batch.create'then result:=boss_private.discount_batch_create(actor,i,request);
 elsif action in('cards.assign','cards.return','cards.print','cards.void')then result:=boss_private.discount_cards_update(actor,action,i,request);
 elsif action='card.claim'then
 perform boss_private.athlete_input(i,array['serial','activation_secret','household_id'],array['serial','activation_secret']);id:=boss_private.discount_card_claim(actor,i->>'serial',i->>'activation_secret',(i->>'household_id')::uuid);result:=jsonb_build_object('membership_id',id,'effective',boss_private.discount_effective(id));
 elsif action='card.replace'then result:=boss_private.discount_card_replace(actor,i,request);
 elsif action='batch.archive'then
 perform boss_private.athlete_input(i,array['batch_id'],array['batch_id']);select organization_id into org from public.discount_card_batches where discount_card_batches.id=(i->>'batch_id')::uuid;perform boss_private.discount_fence(actor,org);
 if not boss_private.discount_role(actor,'boss_bucks.inventory_manage',org)and not boss_private.discount_platform(actor)then raise exception'Batch scope denied'using errcode='PT403';end if;
 if exists(select 1 from public.discount_physical_cards where batch_id=(i->>'batch_id')::uuid and state not in('void','replaced','expired'))then raise exception'Explicitly retire cards before archiving'using errcode='PT409';end if;
 update public.discount_card_batches set status='archived'where discount_card_batches.id=(i->>'batch_id')::uuid;result:=jsonb_build_object('batch_id',i->>'batch_id');perform boss_private.discount_audit(actor,org,null,'card.batch.archived',(i->>'batch_id')::uuid,request);
 elsif action='order.create'then result:=boss_private.discount_order_prepare(actor,command);
 elsif action='order.refund'then result:=boss_private.discount_refund_prepare(actor,command);
 elsif action='order.cancel'then
 perform boss_private.athlete_input(i,array['order_id'],array['order_id']);select *into o from public.discount_orders where discount_orders.id=(i->>'order_id')::uuid;
 perform boss_private.discount_fence(actor,o.organization_id);
 if o.id is null or not boss_private.discount_feature(o.organization_id,'membership_sales')then raise exception'Order scope denied'using errcode='PT403';end if;
 if o.buyer_person_id is distinct from actor and not boss_private.discount_role(actor,'boss_bucks.membership_manage',o.organization_id)then raise exception'Order scope denied'using errcode='PT403';end if;
 perform boss_private.rails_checkout_fence(o.checkout_id);select *into o from public.discount_orders where discount_orders.id=o.id for update;
 if o.state<>'payment_pending'or not exists(select 1 from public.payment_checkouts where id=o.checkout_id and state='ready')or exists(select 1 from public.provider_operations where checkout_id=o.checkout_id and dispatched_at is not null)then raise exception'Submitted payment requires reconciliation'using errcode='PT409';end if;
 -- Use the existing unsubmitted checkout cancellation boundary. Reviewed
 -- attempt invalidation remains reserved for dispatched provider operations.
 update public.payment_checkouts set state='canceled'where payment_checkouts.id=o.checkout_id;
 insert into public.payment_checkout_events(checkout_id,kind)values(o.checkout_id,'canceled');
 update public.discount_orders set state='canceled',updated_at=clock_timestamp()where discount_orders.id=o.id;
 insert into public.discount_order_history(order_id,kind,source_key)values(o.id,'canceled','cancel:'||o.id);result:=jsonb_build_object('order_id',o.id,'state','canceled');
 elsif action='fulfillment.retry'then
 perform boss_private.athlete_input(i,array['order_id'],array['order_id']);select *into o from public.discount_orders where id=(i->>'order_id')::uuid;
 perform boss_private.rails_checkout_fence(o.checkout_id);perform boss_private.discount_fence(actor,o.organization_id);
 if not boss_private.discount_role(actor,'boss_bucks.fulfillment_manage',o.organization_id)then raise exception'Fulfillment scope denied'using errcode='PT403';end if;
 perform boss_private.discount_fulfill(o.id);result:=jsonb_build_object('order_id',o.id);
 elsif action='fulfillment.status'then
 perform boss_private.athlete_input(i,array['fulfillment_id','expected_version','state'],array['fulfillment_id','expected_version','state']);
 select ff.*into f from public.discount_fulfillments ff where ff.id=(i->>'fulfillment_id')::uuid;select oo.*into o from public.discount_orders oo join public.discount_order_items oi on oi.order_id=oo.id where oi.id=f.item_id;
 perform boss_private.discount_fence(actor,o.organization_id);select *into f from public.discount_fulfillments where discount_fulfillments.id=f.id for update;
 if not boss_private.discount_role(actor,'boss_bucks.fulfillment_manage',o.organization_id)or not boss_private.discount_feature(o.organization_id,'physical_cards')then raise exception'Fulfillment scope denied'using errcode='PT403';end if;
 if f.version<>(i->>'expected_version')::bigint or not exists(select 1 from public.discount_fulfillments ff join public.discount_order_items oi on oi.id=ff.item_id where ff.id=f.id and(
 ff.state='allocated'and(i->>'state'='ready_for_pickup'and oi.fulfillment_type='pickup'or i->>'state'='packed'and oi.fulfillment_type='shipping')
 or ff.state='packed'and i->>'state'='shipped'or ff.state in('shipped','ready_for_pickup')and i->>'state'='delivered'))then raise exception'Fulfillment state changed'using errcode='PT409';end if;
 update public.discount_fulfillments set state=i->>'state',version=version+1,updated_at=clock_timestamp()where discount_fulfillments.id=f.id;
 insert into public.discount_fulfillment_history(fulfillment_id,actor_id,state)values(f.id,actor,i->>'state');result:=jsonb_build_object('fulfillment_id',f.id,'state',i->>'state');
 perform boss_private.discount_audit(actor,o.organization_id,null,'product.fulfillment.'||(i->>'state'),f.id,request);
 else raise exception'Unknown product operation'using errcode='PT422';end if;
 -- Never put claim/activation/export secrets into replay receipts or audit data.
 result:=result||jsonb_build_object('action',action,'replayed',false);
 insert into boss_private.discount_requests(request_id,actor_id,action,command_digest,result)values(request,actor,action,h,result-'one_time_cards');return result;
end$$;

create function public.boss_discounts_read(query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.discount_read(query)$$;
create schema boss_discounts_public;
revoke all on schema boss_discounts_public from public,anon,authenticated,service_role,boss_payment_worker;
grant usage on schema boss_discounts_public to anon,authenticated;
create function boss_discounts_public.catalog(organization_id uuid default null,path text default null)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.discount_catalog(organization_id,path)$$;
create function boss_discounts_public.support(command jsonb)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.discount_guest_trial(command)$$;
create function public.boss_discounts_catalog(organization_id uuid default null,path text default null)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_discounts_public.catalog(organization_id,path)$$;
create function public.boss_discounts_support(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_discounts_public.support(command)$$;
revoke all on function boss_discounts_public.catalog(uuid,text),boss_discounts_public.support(jsonb),public.boss_discounts_catalog(uuid,text),public.boss_discounts_support(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_discounts_public.catalog(uuid,text),boss_discounts_public.support(jsonb),public.boss_discounts_catalog(uuid,text),public.boss_discounts_support(jsonb)to anon,authenticated;
alter function boss_private.rails_guest(jsonb)rename to rails_guest_phase7d;
create function boss_private.rails_guest(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare i jsonb:=command->'input';o public.discount_orders;c public.payment_checkouts;ctx jsonb;begin
 if command->>'action'='product.prepare'then return boss_private.discount_order_prepare(null,command);
 elsif command->>'action'='product.status'then
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);perform boss_private.athlete_input(i,array['capability','path'],array['capability','path']);ctx:=boss_private.fundraising_public_context(i->>'path');
 if coalesce(i->>'capability','')!~'^[a-f0-9]{64}$'then raise exception'Product attempt unavailable'using errcode='PT404';end if;
 select *into o from public.discount_orders where guest_digest=encode(sha256(convert_to(i->>'capability','UTF8')),'hex')and campaign_id=(ctx->>'campaign_id')::uuid and fundraiser_id is not distinct from(ctx->>'fundraiser_id')::uuid and share_id is not distinct from(ctx->>'share_id')::uuid;
 if o.id is null then raise exception'Product attempt unavailable'using errcode='PT404';end if;
 select *into c from public.payment_checkouts where id=o.checkout_id;
 return jsonb_build_object('state',o.state,'checkout_state',c.state,'method',c.method,'currency',c.currency,'principal_minor',c.principal_minor,'items',case when o.payment_id is not null then coalesce((select jsonb_agg(jsonb_build_object('item_id',oi.id,'kind',oi.kind,'state',case when oi.kind='physical'then'physical_fulfillment'when dm.subject_id is null then'pending_claim'else'claimed'end))from public.discount_order_items oi left join public.discount_member_sources ds on ds.id=oi.source_id left join public.discount_memberships dm on dm.id=ds.membership_id where oi.order_id=o.id),'[]')else'[]'::jsonb end);
 end if;return boss_private.rails_guest_phase7d(command);
end$$;
revoke all on function boss_private.rails_guest(jsonb),boss_private.rails_guest_phase7d(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
create function public.boss_discounts_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.discount_mutate(command)$$;
revoke all on function public.boss_discounts_read(jsonb),public.boss_discounts_mutate(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function public.boss_discounts_read(jsonb),public.boss_discounts_mutate(jsonb)to authenticated;
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'discount_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;
grant execute on function boss_private.discount_read(jsonb),boss_private.discount_mutate(jsonb)to authenticated;

create table boss_private.discount_guest_claim_requests(
 request_id uuid primary key,command_digest text not null,result jsonb not null,created_at timestamptz not null default clock_timestamp());
alter table boss_private.discount_guest_claim_requests enable row level security;
revoke all on boss_private.discount_guest_claim_requests from public,anon,authenticated,service_role,boss_payment_worker;
create function boss_private.discount_guest_claim(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb:=command->'input';ctx jsonb;intent public.fundraising_intents;o public.discount_orders;s public.discount_member_sources;m public.discount_memberships;
 prior boss_private.discount_guest_claim_requests;claim jsonb;request uuid;h text;org uuid;begin
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);
 perform boss_private.athlete_input(i,array['path','capability','item_id'],array['path','capability']);request:=(command->>'request_id')::uuid;
 if command->>'action'not in('gift.claim','product.claim')or coalesce(i->>'capability','')!~'^[a-f0-9]{64}$'then raise exception'Private claim unavailable'using errcode='PT404';end if;
 ctx:=boss_private.fundraising_public_context(i->>'path');
 if command->>'action'='gift.claim'then
 select *into intent from public.fundraising_intents where capability_digest=encode(sha256(convert_to(i->>'capability','UTF8')),'hex')and campaign_id=(ctx->>'campaign_id')::uuid
 and fundraiser_id is not distinct from(ctx->>'fundraiser_id')::uuid and share_id=(ctx->>'share_id')::uuid;
 select *into s from public.discount_member_sources where intent_id=intent.id and kind='supporter_gift';org:=s.organization_id;
 else
 select *into o from public.discount_orders where guest_digest=encode(sha256(convert_to(i->>'capability','UTF8')),'hex')and campaign_id=(ctx->>'campaign_id')::uuid
 and fundraiser_id is not distinct from(ctx->>'fundraiser_id')::uuid and share_id=(ctx->>'share_id')::uuid;
 select ds.*into s from public.discount_order_items oi join public.discount_member_sources ds on ds.id=oi.source_id where oi.id=(i->>'item_id')::uuid and oi.order_id=o.id;org:=o.organization_id;
 end if;
 perform boss_private.discount_fence(null,org);perform pg_advisory_xact_lock(hashtextextended('boss-discount-guest-claim:'||request,0));
 h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');select *into prior from boss_private.discount_guest_claim_requests where request_id=request;
 if s.id is null or command->>'action'='product.claim'and o.state='review'or not boss_private.discount_feature(org,'discount_membership')or s.starts_at>clock_timestamp()or s.ends_at<=clock_timestamp()
 or exists(select 1 from public.discount_source_revocations where source_id=s.id)then raise exception'Private claim unavailable'using errcode='PT404';end if;
 if prior.request_id is not null then if prior.command_digest<>h then raise exception'Claim request conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true,"one_time_claim_unavailable":true}'::jsonb;end if;
 select *into m from public.discount_memberships where id=s.membership_id for update;
 if m.subject_id is not null or m.state<>'pending_claim'then raise exception'Private claim unavailable'using errcode='PT404';end if;
 perform boss_private.rails_rate('private-membership-claim:'||org,60);claim:=boss_private.discount_claim_issue(m.id);
 insert into boss_private.discount_guest_claim_requests(request_id,command_digest,result)values(request,h,jsonb_build_object('state','pending_claim','action',command->>'action','replayed',false));
 return(claim-'claim_id')||jsonb_build_object('state','pending_claim','action',command->>'action','replayed',false);
end$$;
create or replace function boss_discounts_public.support(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare r jsonb;begin
 if command->>'action'='trial.start'then r:=boss_private.discount_guest_trial(command);else r:=boss_private.discount_guest_claim(command);end if;
 return r||jsonb_build_object('action',command->>'action');end$$;
revoke all on function boss_private.discount_guest_claim(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;

do $$declare d text;needle text;begin
 d:=pg_get_functiondef('boss_private.rails_mutate(jsonb)'::regprocedure);needle:='scope=''campaign''and i->>''purpose''=''fundraising''';
 if position(needle in d)=0 then raise exception'Payment routing checkpoint mismatch';end if;
 d:=replace(d,needle,'scope=''campaign''and i->>''purpose''in(''fundraising'',''products'')');execute d;
end$$;
