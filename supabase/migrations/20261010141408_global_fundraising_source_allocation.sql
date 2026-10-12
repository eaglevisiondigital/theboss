-- Source snapshots and credit ledger integration follow the immutable checkout.
create function boss_private.fundraising_checkout_capture(checkout uuid)returns void
language plpgsql volatile security definer set search_path=''as $$
declare pc public.payment_checkouts;i public.fundraising_intents;o public.discount_orders;
 c public.fundraising_campaigns;f public.fundraising_fundraisers;origin public.fundraising_campaign_origins;
 d public.fundraising_destinations;pp public.fundraising_platform_policies;ap public.fundraising_allocation_policies;
 channel_key text;team uuid;unit uuid;product_revision uuid;provenance jsonb;
begin
 select *into pc from public.payment_checkouts where id=checkout;
 if pc.id is null or pc.purpose not in('fundraising','products')then return;end if;
 if exists(select 1 from public.fundraising_checkout_snapshots where checkout_id=pc.id)then return;end if;
 if pc.purpose='fundraising'then
  select *into i from public.fundraising_intents where id=pc.intent_id;channel_key:=boss_private.fundraising_channel(i.id);
  if channel_key is null then raise exception'Unknown or contradictory fundraising source'using errcode='PT422';end if;
  select *into c from public.fundraising_campaigns where id=i.campaign_id;select *into f from public.fundraising_fundraisers where id=i.fundraiser_id;
  provenance:=i.provenance;team:=(i.provenance->>'team_id')::uuid;unit:=(i.provenance->>'unit_id')::uuid;
 else
  select *into o from public.discount_orders where checkout_id=pc.id;
  if o.id is null or o.campaign_id is null then return;end if;
  select *into c from public.fundraising_campaigns where id=o.campaign_id;select *into f from public.fundraising_fundraisers where id=o.fundraiser_id;
  product_revision:=o.revision_id;
  select case min(kind)when'digital'then'digital_card'when'physical'then'physical_card'end into channel_key
  from public.discount_order_items where order_id=o.id having count(distinct kind)=1;
  if channel_key is null then raise exception'Unknown fundraising product channel'using errcode='PT422';end if;
  provenance:=jsonb_build_object('order_id',o.id,'product_revision_id',o.revision_id,'channel',channel_key);
  team:=f.team_id;unit:=f.unit_id;
 end if;
 perform 1 from public.fundraising_campaigns where fundraising_campaigns.id=c.id for update;
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-platform-policy:'||c.organization_id,0));
 if c.organization_id is distinct from pc.organization_id or c.currency<>pc.currency
  or i.id is not null and(i.amount_minor<>pc.principal_minor or i.currency<>pc.currency)
  or o.id is not null and(o.total_minor<>pc.principal_minor or o.currency<>pc.currency)
  or team is not null and not exists(select 1 from public.teams where id=team and organization_id=c.organization_id)
  or unit is not null and not exists(select 1 from public.organization_units where id=unit and organization_id=c.organization_id)
  or f.id is not null and(f.campaign_id<>c.id or f.organization_id<>c.organization_id or f.team_id is distinct from team or f.unit_id is distinct from unit)
 then raise exception'Canonical checkout attribution mismatch'using errcode='PT422';end if;
 if i.provenance->>'destination_id'is not null then
  select *into d from public.fundraising_destinations where id=(i.provenance->>'destination_id')::uuid;
  if d.campaign_id is distinct from c.id or d.organization_id is distinct from c.organization_id or d.fundraiser_id is distinct from f.id
   or d.team_id is distinct from team or d.unit_id is distinct from (case when team is null then unit end) then raise exception'Exact destination required'using errcode='PT422';end if;
 end if;
 select *into origin from public.fundraising_campaign_origins where campaign_id=c.id;
 select *into pp from public.fundraising_platform_policies where id=boss_private.fundraising_platform_policy(c.organization_id,c.id,channel_key,pc.currency,pc.created_at,product_revision);
 if pp.id is null and exists(select 1 from public.fundraising_platform_policies where organization_id=c.organization_id and(campaign_id=c.id or campaign_id is null)and channel=channel_key and currency=pc.currency and product_revision_id is not distinct from product_revision)
 then raise exception'Approved channel policy unavailable'using errcode='PT409';end if;
 if pp.id is not null and pc.policy_id is distinct from pp.settlement_policy_id then raise exception'Captured platform economics mismatch'using errcode='PT422';end if;
 select *into ap from public.fundraising_allocation_policies where campaign_id=c.id and channel=channel_key and platform_policy_id=pp.id
  and starts_at<=pc.created_at and(ends_at is null or ends_at>pc.created_at)
  and((team_id=team and unit_id is null)or team is null and team_id is null and unit_id is not distinct from unit or team_id is null and unit_id is null)
  order by(num_nonnulls(team_id,unit_id)>0)desc,revision desc limit 1;
 insert into public.fundraising_checkout_snapshots(checkout_id,organization_id,campaign_id,brand_id,destination_id,channel,intent_id,product_order_id,
 fundraiser_id,participant_id,credited_person_id,origin_person_id,referrer_person_id,team_id,unit_id,fund_code,platform_policy_id,allocation_policy_id,
 account_id,routing_id,settlement_policy_id,currency,principal_minor,provenance)
 values(pc.id,c.organization_id,c.id,coalesce(origin.brand_id,(select id from public.fundraising_brands where key='the_boss')),d.id,channel_key,i.id,o.id,f.id,f.participant_id,f.person_id,pc.actor_person_id,d.referrer_person_id,team,unit,origin.fund_code,pp.id,ap.id,
 pc.account_id,pc.routing_id,pc.policy_id,pc.currency,pc.principal_minor,
 jsonb_strip_nulls(provenance||jsonb_build_object('contract_version',1,'brand_binding',case when origin.brand_id is null then'established_boss_deployment'else'explicit_campaign'end,'legal_recipient_organization_id',c.organization_id,'merchant_owner',(select merchant_owner from public.processing_accounts where id=pc.account_id),'settlement_mode',(select settlement_mode from public.processing_accounts where id=pc.account_id))));
end$$;
create function boss_private.fundraising_checkout_capture_trigger()returns trigger language plpgsql volatile security definer set search_path=''as $$
begin
 if tg_table_name='payment_checkouts'then perform boss_private.fundraising_checkout_capture(new.id);
 else perform boss_private.fundraising_checkout_capture(new.checkout_id);end if;
 return new;
end$$;
create trigger fundraising_checkout_snapshot after insert on public.payment_checkouts for each row execute function boss_private.fundraising_checkout_capture_trigger();
create trigger fundraising_product_checkout_snapshot after update of checkout_id on public.discount_orders for each row when(new.checkout_id is not null)execute function boss_private.fundraising_checkout_capture_trigger();

create function boss_private.fundraising_selected_settlement_policy(intent uuid)returns uuid
language plpgsql volatile security definer set search_path=''as $$
declare i public.fundraising_intents;c public.fundraising_campaigns;id uuid;channel_key text;begin
 select *into i from public.fundraising_intents where fundraising_intents.id=intent;select *into c from public.fundraising_campaigns where fundraising_campaigns.id=i.campaign_id;
 perform 1 from public.fundraising_campaigns where fundraising_campaigns.id=c.id for update;
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-platform-policy:'||c.organization_id,0));
 channel_key:=boss_private.fundraising_channel(i.id);if channel_key is null then raise exception'Canonical channel required'using errcode='PT422';end if;
 select settlement_policy_id into id from public.fundraising_platform_policies where fundraising_platform_policies.id=boss_private.fundraising_platform_policy(c.organization_id,c.id,channel_key,i.currency);
 if id is null then
  if exists(select 1 from public.fundraising_platform_policies where organization_id=c.organization_id and(campaign_id=c.id or campaign_id is null)and channel=channel_key and currency=i.currency)then raise exception'Approved channel economics unavailable'using errcode='PT409';end if;
  select p.id into id from public.settlement_policy_revisions p where p.organization_id=c.organization_id and p.purpose='fundraising'and p.currency=i.currency order by p.revision desc limit 1;
 end if;return id;
end$$;
-- Select economics before fee calculation; capture exactly that immutable revision.
do $$declare d text;needle text:='select *into policy from public.settlement_policy_revisions where organization_id=org and purpose=''fundraising''and currency=intent.currency order by revision desc limit 1;';begin
 d:=pg_get_functiondef('boss_private.rails_guest_phase7d(jsonb)'::regprocedure);
 if position(needle in d)=0 then raise exception'Guest policy checkpoint mismatch';end if;
 d:=replace(d,needle,'select *into policy from public.settlement_policy_revisions where id=boss_private.fundraising_selected_settlement_policy(intent.id);');
 d:=replace(d,'external_minor,donor_covered_fee_minor,request_id','external_minor,donor_covered_fee_minor,platform_fee_minor,request_id');
 d:=replace(d,'intent.amount_minor+fee,fee,request','intent.amount_minor+fee+coalesce(policy.platform_fee_minor,0),fee,coalesce(policy.platform_fee_minor,0),request');
 execute d;
end$$;

-- An explicit channel binding freezes the existing Wallet revision at intent creation.
-- Group lineage exists before preparation insertion, so validate its canonical cart/group here.
create function boss_private.fundraising_wallet_snapshot_policy(i public.fundraising_intents)returns uuid
language plpgsql volatile security definer set search_path=''as $$
declare channel_key text;policy uuid;g public.money_board_groups;x public.money_board_carts;begin
 perform 1 from public.fundraising_campaigns where id=i.campaign_id for update;
 if i.provenance->>'channel'='money_board_group'then
  select *into g from public.money_board_groups where id=(i.provenance->>'group_id')::uuid;
  select *into x from public.money_board_carts where id=g.cart_id;
  if x.campaign_id is distinct from i.campaign_id or x.fundraiser_id is distinct from i.fundraiser_id or g.amount_minor is distinct from i.amount_minor or g.currency is distinct from i.currency or num_nonnulls(i.board_id,i.tile_id,i.reservation_id)<>0 then return null;end if;
  channel_key:='money_board';
 else channel_key:=boss_private.fundraising_channel(i.id);end if;
 select wc.wallet_policy_id into policy from public.fundraising_wallet_channel_policies wc where wc.campaign_id=i.campaign_id and wc.channel=channel_key
  and wc.starts_at<=i.created_at and(wc.ends_at is null or wc.ends_at>i.created_at)order by revision desc limit 1;
 if policy is null and not exists(select 1 from public.fundraising_wallet_channel_policies where campaign_id=i.campaign_id and channel=channel_key)then
  select id into policy from public.boss_bucks_policy_revisions where campaign_id=i.campaign_id and created_at<=i.created_at order by revision desc limit 1;
 end if;return policy;
end$$;
do $$declare d text;needle text:='select id into policy from public.boss_bucks_policy_revisions where campaign_id=new.campaign_id and created_at<=new.created_at order by revision desc limit 1;';begin
 d:=pg_get_functiondef('boss_private.bucks_snapshot_source()'::regprocedure);if position(needle in d)=0 then raise exception'Wallet snapshot checkpoint mismatch';end if;
 execute replace(d,needle,'policy:=boss_private.fundraising_wallet_snapshot_policy(new);');
 d:=pg_get_functiondef('boss_private.bucks_issue(uuid)'::regprocedure);needle:='select *into b from public.boss_bucks_fundraiser_bindings where fundraiser_id=f.id;';
 if position(needle in d)=0 then raise exception'Wallet platform envelope checkpoint mismatch';end if;
 execute replace(d,needle,'if exists(select 1 from public.fundraising_checkout_snapshots fs join public.fundraising_platform_policies pp on pp.id=fs.platform_policy_id where fs.intent_id=x.id and not pp.wallet_permitted)then return null;end if;'||needle);
end$$;

-- Memo designation partitions existing verified organization value. It never posts
-- payment, payable, membership or restricted Wallet entries.
create function boss_private.fundraising_credit_issue(payment uuid)returns void
language plpgsql volatile security definer set search_path=''as $$
declare s public.settlement_sources;x public.fundraising_checkout_snapshots;ap public.fundraising_allocation_policies;
 values_minor bigint[];weights bigint[];basis bigint;categories text[];beneficiaries uuid[];idx int;
begin
 select *into s from public.settlement_sources where payment_id=payment;
 if s.payment_id is null or s.purpose='unallocated'or not exists(select 1 from public.settlement_events where payment_id=s.payment_id and kind='settled')then return;end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-credit-source:'||payment,0));
 if exists(select 1 from public.fundraising_credit_sources where payment_id=payment)then return;end if;
 select fs.*into x from public.external_payment_tenders t join public.fundraising_checkout_snapshots fs on fs.checkout_id=t.checkout_id where t.payment_id=s.payment_id and t.original_payment_id is null;
 select *into ap from public.fundraising_allocation_policies where id=x.allocation_policy_id;
 if ap.id is null then return;end if;
 if s.organization_id<>x.organization_id or s.currency<>x.currency or s.policy_id is distinct from x.settlement_policy_id then raise exception'Credit source lineage mismatch'using errcode='PT422';end if;
 select amount_minor into basis from public.settlement_events where payment_id=s.payment_id and kind='settled';
 basis:=coalesce(basis,0);
 weights:=array[ap.organization_bps::bigint,ap.destination_bps::bigint,ap.participant_bps::bigint];
 if x.participant_id is null then weights[1]:=weights[1]+weights[3];weights[3]:=0;end if;
 if num_nonnulls(x.team_id,x.unit_id)=0 then weights[1]:=weights[1]+weights[2];weights[2]:=0;end if;
 values_minor:=boss_private.fundraising_hamilton(basis,weights);
 categories:=array['organization_designation',case when x.team_id is not null then'team_designation'else'unit_designation'end,'participant_credit'];
 beneficiaries:=array[x.organization_id,coalesce(x.team_id,x.unit_id),x.participant_id];
 insert into public.fundraising_credit_sources(payment_id,checkout_id,organization_id,campaign_id,policy_id,currency,original_minor)
 values(s.payment_id,x.checkout_id,x.organization_id,x.campaign_id,ap.id,x.currency,basis);
 for idx in 1..3 loop if values_minor[idx]>0 then
  insert into public.fundraising_credit_entries(payment_id,category,beneficiary_id,amount_minor,algorithm)
  values(s.payment_id,categories[idx],beneficiaries[idx],values_minor[idx],'hamilton_original_cumulative_v1');
 end if;end loop;
end$$;
alter function boss_private.rails_settlement_match(uuid,uuid,bigint)rename to rails_settlement_match_before_global;
create function boss_private.rails_settlement_match(payment uuid,event uuid,actual_fee bigint)returns jsonb
language plpgsql volatile security definer set search_path=''as $$declare result jsonb;begin
 result:=boss_private.rails_settlement_match_before_global(payment,event,actual_fee);
 if result->>'state'='settled'then perform boss_private.fundraising_credit_issue(payment);end if;return result;
end$$;

create function boss_private.fundraising_credit_correct(correction uuid)returns void
language plpgsql volatile security definer set search_path=''as $$
declare ec public.external_payment_corrections;s public.fundraising_credit_sources;ids uuid[];originals bigint[];remaining bigint[];
 allocated bigint[];target bigint;already bigint;to_reverse bigint;total numeric;leftover bigint;idx int;n int;k bigint;best int;remainders numeric[];part bigint;
begin
 select *into ec from public.external_payment_corrections where reversal_payment_id=correction;
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-credit-source:'||ec.original_payment_id,0));
 select *into s from public.fundraising_credit_sources where payment_id=ec.original_payment_id;if s.payment_id is null then return;end if;
 if exists(select 1 from public.fundraising_credit_entries where correction_id=correction)then return;end if;
 -- Refund impact only. Payouts and recovery offsets must not reduce fundraising credit.
 select least(s.original_minor,coalesce(sum(sp.amount_minor),0))into target
 from public.settlement_journals sj join public.settlement_postings sp on sp.journal_id=sj.id
 join public.settlement_accounts sa on sa.id=sp.account_id
 where sj.payment_id=s.payment_id and sj.kind='correction'and sj.created_at>s.created_at
 and sa.kind in('organization_payable','organization_deficit');
 select -coalesce(sum(amount_minor),0)into already from public.fundraising_credit_entries where payment_id=s.payment_id and correction_id is not null;
 to_reverse:=target-already;if to_reverse<=0 then return;end if;
 select array_agg(e.id order by e.category,e.beneficiary_id),array_agg(e.amount_minor order by e.category,e.beneficiary_id),
 array_agg(e.amount_minor+coalesce((select sum(r.amount_minor)from public.fundraising_credit_entries r where r.payment_id=e.payment_id and r.category=e.category and r.beneficiary_id=e.beneficiary_id and r.correction_id is not null),0)order by e.category,e.beneficiary_id)
 into ids,originals,remaining from public.fundraising_credit_entries e where e.payment_id=s.payment_id and e.correction_id is null;
 n:=coalesce(array_length(ids,1),0);if n=0 or to_reverse>(select sum(v)from unnest(remaining)v)then raise exception'Credit correction exceeds original source'using errcode='PT422';end if;
 allocated:=array_fill(0::bigint,array[n]);leftover:=to_reverse;
 while leftover>0 loop
  total:=0;for idx in 1..n loop if remaining[idx]>allocated[idx]then total:=total+originals[idx];end if;end loop;
  remainders:=array_fill(-1::numeric,array[n]);part:=leftover;
  for idx in 1..n loop if remaining[idx]>allocated[idx]then
   k:=least(div(part::numeric*originals[idx],total)::bigint,remaining[idx]-allocated[idx]);allocated[idx]:=allocated[idx]+k;leftover:=leftover-k;
   if remaining[idx]>allocated[idx]then remainders[idx]:=mod(part::numeric*originals[idx],total);end if;
  end if;end loop;
  for k in 1..n loop exit when leftover=0;best:=0;for idx in 1..n loop if remainders[idx]>=0 and(best=0 or remainders[idx]>remainders[best])then best:=idx;end if;end loop;
   exit when best=0;allocated[best]:=allocated[best]+1;leftover:=leftover-1;remainders[best]:=-1;
  end loop;
 end loop;
 for idx in 1..n loop if allocated[idx]>0 then
  insert into public.fundraising_credit_entries(payment_id,correction_id,category,beneficiary_id,amount_minor,algorithm)
  select payment_id,correction,category,beneficiary_id,-allocated[idx],'hamilton_original_cumulative_v1'from public.fundraising_credit_entries where id=ids[idx];
 end if;end loop;
end$$;
alter function boss_private.rails_external_correct(uuid,uuid,text,bigint,jsonb,uuid)rename to rails_external_correct_before_global;
create function boss_private.rails_external_correct(payment uuid,event uuid,p_kind text,principal bigint,allocations jsonb default '[]',refund uuid default null)returns uuid
language plpgsql volatile security definer set search_path=''as $$declare id uuid;begin
 id:=boss_private.rails_external_correct_before_global(payment,event,p_kind,principal,allocations,refund);
 if id is not null then perform boss_private.fundraising_credit_correct(id);end if;return id;
end$$;

-- Deferrable conservation checks verify tenant/currency/category identity as well as cents.
create function boss_private.fundraising_credit_proof()returns trigger language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare s public.fundraising_credit_sources;x public.fundraising_checkout_snapshots;id uuid;begin
 id:=case tg_table_name when'fundraising_credit_sources'then new.payment_id else new.payment_id end;
 select *into s from public.fundraising_credit_sources where payment_id=id;select *into x from public.fundraising_checkout_snapshots where checkout_id=s.checkout_id;
 if s.organization_id<>x.organization_id or s.campaign_id<>x.campaign_id or s.currency<>x.currency or s.policy_id is distinct from x.allocation_policy_id
  or(select coalesce(sum(amount_minor),0)from public.fundraising_credit_entries where payment_id=id and correction_id is null)<>s.original_minor
  or exists(select 1 from public.fundraising_credit_entries e where e.payment_id=id and(case e.category when'organization_designation'then e.beneficiary_id<>s.organization_id when'team_designation'then e.beneficiary_id is distinct from x.team_id when'unit_designation'then e.beneficiary_id is distinct from x.unit_id else e.beneficiary_id is distinct from x.participant_id end))
  or exists(select 1 from public.fundraising_credit_entries e join public.external_payment_corrections ec on ec.reversal_payment_id=e.correction_id where e.payment_id=id and ec.original_payment_id<>id)
  or exists(select 1 from public.fundraising_credit_entries where payment_id=id group by category,beneficiary_id having sum(amount_minor)<0)
 then raise exception'Invalid immutable credit lineage or conservation'using errcode='23514';end if;return null;
end$$;
create constraint trigger fundraising_credit_source_proof after insert on public.fundraising_credit_sources deferrable initially deferred for each row execute function boss_private.fundraising_credit_proof();
create constraint trigger fundraising_credit_entry_proof after insert on public.fundraising_credit_entries deferrable initially deferred for each row execute function boss_private.fundraising_credit_proof();
do $$declare p record;begin
 for p in select oid::regprocedure sig from pg_proc where pronamespace='boss_private'::regnamespace and(proname like'fundraising_%'or proname in('rails_settlement_match','rails_settlement_match_before_global','rails_external_correct','rails_external_correct_before_global'))loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.sig);end loop;
end$$;
grant execute on function boss_private.fundraising_allocation_command(jsonb),boss_private.fundraising_mutate(jsonb),boss_private.fundraising_read(jsonb),boss_private.fundraising_navigation()to authenticated;
