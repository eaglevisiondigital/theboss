-- New rounding metadata belongs only to explicitly captured amendment policies.
-- It describes the existing settlement postings, not another financial liability.
create table public.fundraising_cash_rounding_sources(
 payment_id uuid primary key references public.settlement_sources(payment_id),checkout_id uuid not null references public.fundraising_checkout_snapshots(checkout_id),
 principal_minor bigint not null check(principal_minor>=0),organization_minor bigint not null check(organization_minor>=0),
 product_cost_minor bigint not null check(product_cost_minor>=0),platform_minor bigint not null check(platform_minor>=0),
 algorithm text not null default 'hamilton_original_capped_v1'check(algorithm='hamilton_original_capped_v1'),
 created_at timestamptz not null default clock_timestamp(),check(principal_minor=organization_minor+product_cost_minor+platform_minor));
create index fundraising_cash_rounding_checkout_idx on public.fundraising_cash_rounding_sources(checkout_id);
create table public.fundraising_cash_rounding_corrections(
 correction_id uuid primary key references public.external_payment_corrections(reversal_payment_id),payment_id uuid not null references public.fundraising_cash_rounding_sources(payment_id),
 principal_minor bigint not null check(principal_minor>=0),organization_minor bigint not null check(organization_minor>=0),
 product_cost_minor bigint not null check(product_cost_minor>=0),platform_minor bigint not null check(platform_minor>=0),
 created_at timestamptz not null default clock_timestamp(),check(principal_minor=organization_minor+product_cost_minor+platform_minor));
create index fundraising_cash_rounding_correction_source_idx on public.fundraising_cash_rounding_corrections(payment_id);
do $$declare t text;begin foreach t in array array['fundraising_cash_rounding_sources','fundraising_cash_rounding_corrections']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);
 execute format('create trigger immutable_%I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t,t);
 execute format('create trigger immutable_truncate_%I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t,t);
end loop;end$$;
create function boss_private.fundraising_hamilton_capped(total bigint,weights bigint[],caps bigint[])returns bigint[]
language plpgsql immutable set search_path=''as $$
declare n int:=coalesce(array_length(weights,1),0);outcomes bigint[];remainders numeric[];leftover bigint:=total;
 denominator numeric;part bigint;k bigint;idx int;best int;step int;
begin
 if total<0 or n<1 or n>1000 or array_lower(weights,1)<>1 or array_lower(caps,1)<>1 or array_length(caps,1)<>n
 or exists(select 1 from unnest(weights)w where w is null or w<0)or exists(select 1 from unnest(caps)c where c is null or c<0)
 or exists(select 1 from generate_series(1,n)i where caps[i]>0 and weights[i]=0)
 or total>(select sum(v::numeric)from unnest(caps)v)then raise exception'Invalid capped allocation'using errcode='PT422';end if;
 outcomes:=array_fill(0::bigint,array[n]);
 while leftover>0 loop
  denominator:=0;for idx in 1..n loop if caps[idx]>outcomes[idx]then denominator:=denominator+weights[idx];end if;end loop;
  if denominator=0 then raise exception'No remaining allocation weight'using errcode='PT422';end if;
  part:=leftover;remainders:=array_fill(-1::numeric,array[n]);
  for idx in 1..n loop if caps[idx]>outcomes[idx]then
   k:=least(div(part::numeric*weights[idx],denominator)::bigint,caps[idx]-outcomes[idx]);outcomes[idx]:=outcomes[idx]+k;leftover:=leftover-k;
   if caps[idx]>outcomes[idx]then remainders[idx]:=mod(part::numeric*weights[idx],denominator);end if;
  end if;end loop;
  for step in 1..n loop exit when leftover=0;best:=0;for idx in 1..n loop if remainders[idx]>=0 and(best=0 or remainders[idx]>remainders[best])then best:=idx;end if;end loop;
   exit when best=0;outcomes[best]:=outcomes[best]+1;remainders[best]:=-1;leftover:=leftover-1;
  end loop;
 end loop;return outcomes;
end$$;
create function boss_private.fundraising_cash_split(payment uuid,principal bigint)returns bigint[]language plpgsql volatile security definer set search_path=''as $$
declare s public.settlement_sources;x public.fundraising_checkout_snapshots;p public.settlement_policy_revisions;a bigint[];begin
 select *into s from public.settlement_sources where payment_id=payment;
 select fs.*into x from public.external_payment_tenders t join public.fundraising_checkout_snapshots fs on fs.checkout_id=t.checkout_id where t.payment_id=payment and t.original_payment_id is null;
 select *into p from public.settlement_policy_revisions where id=x.settlement_policy_id;
 if x.platform_policy_id is null or x.channel not in('money_board','direct_support')or p.id is distinct from s.policy_id then raise exception'Captured amendment policy required'using errcode='PT422';end if;
 a:=boss_private.fundraising_hamilton(principal,array[p.organization_basis_points::bigint,p.product_cost_basis_points::bigint,p.platform_basis_points::bigint]);
 insert into public.fundraising_cash_rounding_sources(payment_id,checkout_id,principal_minor,organization_minor,product_cost_minor,platform_minor)
 values(payment,x.checkout_id,principal,a[1],a[2],a[3]);return a;
end$$;
create function boss_private.fundraising_cash_refund(payment uuid,correction uuid,principal bigint)returns bigint[]language plpgsql volatile security definer set search_path=''as $$
declare s public.fundraising_cash_rounding_sources;r public.fundraising_cash_rounding_corrections;caps bigint[];a bigint[];begin
 select *into s from public.fundraising_cash_rounding_sources where payment_id=payment;
 select *into r from public.fundraising_cash_rounding_corrections where correction_id=correction;
 if r.correction_id is not null then return array[r.organization_minor,r.product_cost_minor,r.platform_minor];end if;
 if not exists(select 1 from public.external_payment_corrections where reversal_payment_id=correction and original_payment_id=payment and principal_minor=principal)then raise exception'Original correction required'using errcode='PT422';end if;
 select array[s.organization_minor-coalesce(sum(organization_minor),0),s.product_cost_minor-coalesce(sum(product_cost_minor),0),s.platform_minor-coalesce(sum(platform_minor),0)]into caps
 from public.fundraising_cash_rounding_corrections where payment_id=payment;
 a:=boss_private.fundraising_hamilton_capped(principal,array[s.organization_minor,s.product_cost_minor,s.platform_minor],caps);
 insert into public.fundraising_cash_rounding_corrections(correction_id,payment_id,principal_minor,organization_minor,product_cost_minor,platform_minor)values(correction,payment,principal,a[1],a[2],a[3]);return a;
end$$;
do $$declare d text;needle text;replacement text;begin
 d:=pg_get_functiondef('boss_private.rails_settlement_match_before_global(uuid,uuid,bigint)'::regprocedure);
 needle:='orgshare:=floor(net_principal::numeric*p.organization_basis_points/10000)::bigint;'||chr(10)||' cost:=floor(net_principal::numeric*p.product_cost_basis_points/10000)::bigint;';
 if position(needle in d)=0 then raise exception'Cash Hamilton settlement checkpoint mismatch';end if;
 replacement:='if exists(select 1 from public.external_payment_tenders et join public.fundraising_checkout_snapshots fs on fs.checkout_id=et.checkout_id where et.payment_id=s.payment_id and fs.platform_policy_id is not null and fs.channel in(''money_board'',''direct_support''))then cash_split:=boss_private.fundraising_cash_split(s.payment_id,net_principal);orgshare:=cash_split[1];cost:=cash_split[2];else '||needle||'end if;';
 d:=replace(d,'net_gross bigint;begin','net_gross bigint;cash_split bigint[];begin');d:=replace(d,needle,replacement);execute d;
 d:=pg_get_functiondef('boss_private.rails_external_correct_before_global(uuid,uuid,text,bigint,jsonb,uuid)'::regprocedure);
 needle:='share:=floor((remaining+principal)::numeric*policy.organization_basis_points/10000)::bigint-floor(remaining::numeric*policy.organization_basis_points/10000)::bigint;cost:=floor((remaining+principal)::numeric*policy.product_cost_basis_points/10000)::bigint-floor(remaining::numeric*policy.product_cost_basis_points/10000)::bigint;';
 if position(needle in d)=0 then raise exception'Cash Hamilton correction checkpoint mismatch';end if;
 replacement:='if exists(select 1 from public.fundraising_cash_rounding_sources where payment_id=p.id)then cash_split:=boss_private.fundraising_cash_refund(p.id,reversal,principal);share:=cash_split[1];cost:=cash_split[2];else '||needle||'end if;';
 d:=replace(d,'policy public.settlement_policy_revisions;begin','policy public.settlement_policy_revisions;cash_split bigint[];begin');execute replace(d,needle,replacement);
end$$;

-- The public board UI and old fundraising_raised fields retain their original
-- definitions. v3 private reporting labels provider cash, donations and products separately.
create function boss_private.fundraising_contract_proof()returns trigger language plpgsql security definer set search_path=''as $$
declare pp public.fundraising_platform_policies;ap public.fundraising_allocation_policies;pc public.payment_checkouts;
 c public.fundraising_campaigns;d public.fundraising_destinations;b public.money_boards;f public.fundraising_fundraisers;
 r public.settlement_policy_revisions;pr public.discount_product_revisions;
begin
 if tg_table_name='fundraising_platform_policies'then
  select *into r from public.settlement_policy_revisions where id=new.settlement_policy_id;
  select *into c from public.fundraising_campaigns where id=new.campaign_id;
  select *into pr from public.discount_product_revisions where id=new.product_revision_id;
  if r.organization_id is distinct from new.organization_id or r.currency is distinct from new.currency
   or r.purpose is distinct from(case when new.channel in('digital_card','physical_card')then'products'else'fundraising'end)
   or c.id is not null and c.currency<>new.currency
   or new.product_revision_id is not null and(pr.organization_id is distinct from new.organization_id or pr.currency is distinct from new.currency or pr.settlement_policy_id is distinct from r.id
    or not exists(select 1 from public.discount_products where id=pr.product_id and kind=case new.channel when'digital_card'then'digital'else'physical'end))
  then raise exception'Invalid platform economics lineage'using errcode='23514';end if;
 elsif tg_table_name='fundraising_allocation_policies'then
  select *into pp from public.fundraising_platform_policies where id=new.platform_policy_id;
  select *into c from public.fundraising_campaigns where id=new.campaign_id;
  if pp.organization_id is distinct from new.organization_id or pp.channel is distinct from new.channel or pp.currency is distinct from c.currency
   or pp.campaign_id is not null and pp.campaign_id<>new.campaign_id or new.participant_bps>pp.participant_credit_max_bps
   or new.starts_at<pp.starts_at or pp.ends_at is not null and(new.ends_at is null or new.ends_at>pp.ends_at)
  then raise exception'Invalid allocation envelope lineage'using errcode='23514';end if;
 elsif tg_table_name='fundraising_wallet_channel_policies'then
  if not exists(select 1 from public.boss_bucks_policy_revisions where id=new.wallet_policy_id and campaign_id=new.campaign_id and organization_id=new.organization_id and new.channel=any(channels))
  then raise exception'Invalid independent Wallet channel lineage'using errcode='23514';end if;
 elsif tg_table_name='money_boards'then
  select *into c from public.fundraising_campaigns where id=new.campaign_id;
  if new.unit_id is not null and not exists(select 1 from public.organization_units where id=new.unit_id and organization_id=c.organization_id)
  then raise exception'Cross-tenant unit board'using errcode='23514';end if;
 elsif tg_table_name='fundraising_destinations'then
  select *into b from public.money_boards where id=new.board_id;
  select *into f from public.fundraising_fundraisers where id=new.fundraiser_id;
  if b.id is not null and(b.campaign_id<>new.campaign_id or b.fundraiser_id is distinct from new.fundraiser_id or b.team_id is distinct from(case when f.id is null then new.team_id end)or b.unit_id is distinct from(case when f.id is null then new.unit_id end))
   or f.id is not null and(f.team_id is distinct from new.team_id or f.unit_id is distinct from(case when new.team_id is null then new.unit_id else(select parent_unit_id from public.teams where id=new.team_id)end))
  then raise exception'Invalid exact destination lineage'using errcode='23514';end if;
 else
  select *into pc from public.payment_checkouts where id=new.checkout_id;
  select *into pp from public.fundraising_platform_policies where id=new.platform_policy_id;
  select *into ap from public.fundraising_allocation_policies where id=new.allocation_policy_id;
  if pc.organization_id is distinct from new.organization_id or pc.currency is distinct from new.currency or pc.principal_minor is distinct from new.principal_minor
   or pc.account_id is distinct from new.account_id or pc.routing_id is distinct from new.routing_id or pc.policy_id is distinct from new.settlement_policy_id
   or pc.intent_id is distinct from new.intent_id or new.intent_id is not null and boss_private.fundraising_channel(new.intent_id)is distinct from new.channel
   or pp.id is not null and(pp.settlement_policy_id is distinct from pc.policy_id or pp.channel<>new.channel or pp.currency<>new.currency)
   or ap.id is not null and(ap.platform_policy_id is distinct from pp.id or ap.channel<>new.channel or ap.campaign_id<>new.campaign_id
    or ap.team_id is not null and ap.team_id is distinct from new.team_id or ap.unit_id is not null and ap.unit_id is distinct from new.unit_id)
  then raise exception'Invalid immutable checkout contract'using errcode='23514';end if;
 end if;return null;
end$$;
create constraint trigger fundraising_platform_policy_proof after insert on public.fundraising_platform_policies deferrable initially deferred for each row execute function boss_private.fundraising_contract_proof();
create constraint trigger fundraising_allocation_policy_proof after insert on public.fundraising_allocation_policies deferrable initially deferred for each row execute function boss_private.fundraising_contract_proof();
create constraint trigger fundraising_wallet_channel_proof after insert on public.fundraising_wallet_channel_policies deferrable initially deferred for each row execute function boss_private.fundraising_contract_proof();
create constraint trigger fundraising_destination_proof after insert on public.fundraising_destinations deferrable initially deferred for each row execute function boss_private.fundraising_contract_proof();
create constraint trigger fundraising_unit_board_proof after insert on public.money_boards deferrable initially deferred for each row execute function boss_private.fundraising_contract_proof();
create constraint trigger fundraising_checkout_contract_proof after insert on public.fundraising_checkout_snapshots deferrable initially deferred for each row execute function boss_private.fundraising_contract_proof();
create function boss_private.fundraising_allocation_read(query jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;c public.fundraising_campaigns;team uuid;unit uuid;after_id uuid;org uuid;rows jsonb;can_manage boolean;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(query,array['campaign_id','team_id','unit_id','after'],array['campaign_id']);
 select *into c from public.fundraising_campaigns where id=(query->>'campaign_id')::uuid;
 team:=(query->>'team_id')::uuid;unit:=(query->>'unit_id')::uuid;after_id:=(query->>'after')::uuid;org:=c.organization_id;
 if c.id is null or num_nonnulls(team,unit)>1 then raise exception'Exact campaign scope required'using errcode='PT403';end if;
 can_manage:=boss_private.fundraising_allocation_manage(actor,c.id,team,unit);
 if not can_manage and not boss_private.fundraising_role(actor,'fundraising.financial_view',org,coalesce(unit,(select parent_unit_id from public.teams where id=team and organization_id=org)),team)then raise exception'Allocation report restricted'using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('checkout_id',x.checkout_id,'channel',x.channel,'currency',x.currency,'state',pc.state,
 'policy_snapshot',jsonb_build_object('brand_id',x.brand_id,'fund_code',x.fund_code,'platform_policy_id',x.platform_policy_id,'allocation_policy_id',x.allocation_policy_id,'settlement_policy_id',x.settlement_policy_id,'routing_id',x.routing_id,'account_id',x.account_id),
 'gross_verified_cash_minor',coalesce(s.gross_minor,0),
 'gross_donation_minor',case when x.channel in('money_board','direct_support')then coalesce(s.principal_minor,0)else 0 end,
 'confirmed_donation_refunds_minor',case when x.channel in('money_board','direct_support')then coalesce((select sum(ec.principal_minor)from public.external_payment_corrections ec where ec.original_payment_id=s.payment_id),0)else 0 end,
 'net_donation_minor',case when x.channel in('money_board','direct_support')then coalesce(s.principal_minor,0)-coalesce((select sum(ec.principal_minor)from public.external_payment_corrections ec where ec.original_payment_id=s.payment_id),0)else 0 end,
 'reserved_tile_value_minor',coalesce((select sum(gi.amount_minor)from public.money_board_checkout_preparations cp join public.money_board_group_items gi on gi.group_id=cp.group_id where cp.intent_id=x.intent_id and s.payment_id is null and boss_private.rails_hold(pc.id)),0),
 'permanently_claimed_tiles',(select count(*)from public.money_board_tile_claims cl join public.fundraising_success_evidence fe on fe.id=cl.evidence_id where fe.intent_id=x.intent_id),
 'gross_digital_card_sales_minor',case when x.channel='digital_card'then coalesce(s.principal_minor,0)else 0 end,
 'gross_physical_card_sales_minor',case when x.channel='physical_card'then coalesce(s.principal_minor,0)else 0 end,
 'product_sale_refunds_minor',case when x.channel in('digital_card','physical_card')then coalesce((select sum(principal_minor)from public.external_payment_corrections where original_payment_id=s.payment_id),0)else 0 end,
 'net_product_sales_minor',case when x.channel in('digital_card','physical_card')then coalesce(s.principal_minor,0)-coalesce((select sum(principal_minor)from public.external_payment_corrections where original_payment_id=s.payment_id),0)else 0 end,
 'product_sale_organization_credit_minor',coalesce((select sum(cr.amount_minor)from public.discount_product_credits cr join public.discount_order_items oi on oi.id=cr.item_id where oi.order_id=x.product_order_id),0),
 'platform_revenue_minor',coalesce((select -sum(sp.amount_minor)from public.settlement_journals sj join public.settlement_postings sp on sp.journal_id=sj.id join public.settlement_accounts sa on sa.id=sp.account_id where sj.payment_id=s.payment_id and sa.kind='platform_share'),0),
 'actual_processor_cost_minor',(select processor_fee_minor from public.settlement_events where payment_id=s.payment_id and kind='settled'),
 'organization_allocation_minor',coalesce((select amount_minor from public.settlement_events where payment_id=s.payment_id and kind='settled'),0),
 'noncash_designations',coalesce((select jsonb_agg(jsonb_build_object('category',category,'amount_minor',amount))from(select category,sum(amount_minor)amount from public.fundraising_credit_entries where payment_id=s.payment_id group by category)e),'[]'),
 'wallet_earning_minor',coalesce((select sum(g.amount_minor)from public.boss_bucks_grants g where g.intent_id=x.intent_id),0),
 'wallet_source_correction_minor',coalesce((select sum(g.amount_minor-coalesce((select entitlement_minor from public.boss_bucks_source_corrections bc where bc.grant_id=g.id order by created_at desc,id desc limit 1),g.amount_minor))from public.boss_bucks_grants g where g.intent_id=x.intent_id),0),
 'pending_payment_minor',case when s.payment_id is null and boss_private.rails_hold(pc.id)then pc.principal_minor else 0 end,
 'provider_settlement',case when s.payment_id is null then'awaiting_payment'when exists(select 1 from public.settlement_events where payment_id=s.payment_id and kind='settled')then'settled'else'pending'end,
 'organization_payable_minor',coalesce(boss_private.rails_source_payable(s.payment_id),0),
 'organization_paid_minor',coalesce((select sum(sp.amount_minor)from public.settlement_journals sj join public.settlement_postings sp on sp.journal_id=sj.id join public.settlement_accounts sa on sa.id=sp.account_id where sj.payment_id=s.payment_id and sj.kind='remittance'and sa.kind='organization_payable'),0),
 'organization_deficit_minor',coalesce((select sum(sd.amount_minor-coalesce((select sum(amount_minor)from public.settlement_deficit_offsets where deficit_id=sd.id),0))from public.settlement_deficits sd join public.external_payment_corrections ec on ec.reversal_payment_id=sd.correction_payment_id where ec.original_payment_id=s.payment_id),0),
 'organization_payout_status',case when s.settlement_mode='direct_provider'then'external_provider_owned'when s.payment_id is null then'awaiting_payment'else'boss_settlement_obligation'end
 )order by x.checkout_id),'[]')into rows
 from(select *from public.fundraising_checkout_snapshots where campaign_id=c.id and organization_id=org
  and(team is null or team_id=team)and(unit is null or unit_id=unit)and(after_id is null or checkout_id>after_id)order by checkout_id limit 100)x
 join public.payment_checkouts pc on pc.id=x.checkout_id left join public.external_payment_tenders et on et.checkout_id=pc.id and et.original_payment_id is null left join public.settlement_sources s on s.payment_id=et.payment_id;
 return boss_private.bucks_safe_money_json(jsonb_build_object('version',3,'campaign_id',c.id,'organization_id',org,'currency',c.currency,'can_manage',can_manage,'can_manage_platform',boss_private.fundraising_platform_actor(actor),
 'scope',jsonb_build_object('team_id',team,'unit_id',unit),'accounting_kind','noncash_designation','source_page',rows,'page_limit',100,
 'next_after',case when jsonb_array_length(rows)=100 then rows->99->>'checkout_id'end,
 'platform_policies',coalesce((select jsonb_agg(jsonb_build_object('id',pp.id,'revision',pp.revision,'channel',pp.channel,'settlement_policy_id',pp.settlement_policy_id,'participant_credit_max_bps',pp.participant_credit_max_bps,'wallet_permitted',pp.wallet_permitted,'starts_at',pp.starts_at,'ends_at',pp.ends_at))from(select *from public.fundraising_platform_policies where organization_id=org and(campaign_id=c.id or campaign_id is null)order by created_at desc,id limit 100)pp),'[]'),
 'allocation_policies',coalesce((select jsonb_agg(jsonb_build_object('id',ap.id,'revision',ap.revision,'channel',ap.channel,'platform_policy_id',ap.platform_policy_id,'organization_bps',ap.organization_bps,'destination_bps',ap.destination_bps,'participant_bps',ap.participant_bps,'starts_at',ap.starts_at,'ends_at',ap.ends_at))from(select *from public.fundraising_allocation_policies where campaign_id=c.id and(team_id is not distinct from team and unit_id is not distinct from unit)order by revision desc,id limit 100)ap),'[]')));
end$$;
create function public.boss_fundraising_allocation_read(query jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.fundraising_allocation_read(query)$$;
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='boss_private'::regnamespace and proname like'fundraising_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.sig);end loop;end$$;
revoke all on function public.boss_fundraising_allocation_read(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function public.boss_fundraising_allocation_read(jsonb),boss_private.fundraising_allocation_read(jsonb),boss_private.fundraising_allocation_command(jsonb),boss_private.fundraising_read(jsonb),boss_private.fundraising_mutate(jsonb),boss_private.fundraising_navigation()to authenticated;
