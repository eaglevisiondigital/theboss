-- Current exact-resource checks and immutable policy selection.
create function boss_private.fundraising_hamilton(total bigint,weights bigint[]) returns bigint[]
language plpgsql immutable set search_path='' as $$
declare n int:=coalesce(array_length(weights,1),0);s numeric;outcomes bigint[];remainders numeric[];leftover bigint;idx int;best int;
begin
 if total<0 or total>9007199254740991 or n<1 or n>1000 or array_lower(weights,1)<>1 or exists(select 1 from unnest(weights)w where w is null or w<0)then raise exception 'Invalid integer allocation'using errcode='PT422';end if;
 select sum(w::numeric)into s from unnest(weights)w;if s<=0 then raise exception 'Positive allocation weights required'using errcode='PT422';end if;
 outcomes:=array_fill(0::bigint,array[n]);remainders:=array_fill(0::numeric,array[n]);leftover:=total;
 for idx in 1..n loop outcomes[idx]:=div(total::numeric*weights[idx],s)::bigint;remainders[idx]:=mod(total::numeric*weights[idx],s);leftover:=leftover-outcomes[idx];end loop;
 while leftover>0 loop
  best:=0;for idx in 1..n loop if weights[idx]>0 and (best=0 or remainders[idx]>remainders[best])then best:=idx;end if;end loop;
  outcomes[best]:=outcomes[best]+1;remainders[best]:=-1;leftover:=leftover-1;
 end loop;return outcomes;
end$$;
create function boss_private.fundraising_allocation_manage(actor uuid,campaign uuid,team uuid default null,unit uuid default null)returns boolean
language plpgsql volatile security definer set search_path=''as $$
declare c public.fundraising_campaigns;begin
 select *into c from public.fundraising_campaigns where id=campaign;
 if c.id is null or not boss_private.fundraising_module(c.organization_id,'fundraising')or num_nonnulls(team,unit)>1 then return false;end if;
 if team is not null and not exists(select 1 from public.teams where id=team and organization_id=c.organization_id and status='active')then return false;end if;
 if unit is not null and not exists(select 1 from public.organization_units where id=unit and organization_id=c.organization_id and status='active')then return false;end if;
 if c.scope='selected'and num_nonnulls(team,unit)=1 and not exists(select 1 from public.fundraising_targets where campaign_id=c.id and(team_id=team or unit_id=unit))then return false;end if;
 if boss_private.fundraising_role(actor,'fundraising.manage',c.organization_id)then return true;end if;
 return num_nonnulls(team,unit)=1 and exists(select 1 from public.fundraising_allocation_delegations d
  where d.person_id=actor and d.campaign_id=c.id and d.team_id is not distinct from team and d.unit_id is not distinct from unit
  and d.revoked_at is null and d.starts_at<=clock_timestamp()and d.ends_at>clock_timestamp())
 and exists(select 1 from public.people where id=actor and status='active')
 and exists(select 1 from public.organization_memberships where organization_id=c.organization_id and person_id=actor and status='active'and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp()))
 and(team is null or exists(select 1 from public.team_memberships where organization_id=c.organization_id and team_id=team and person_id=actor and status='active'and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp())));
end$$;
create function boss_private.fundraising_platform_policy(org uuid,campaign uuid,channel_key text,currency_key text,at_time timestamptz default clock_timestamp(),product_revision uuid default null)returns uuid
language sql volatile security definer set search_path=''as $$
 select p.id from public.fundraising_platform_policies p where p.organization_id=org and(p.campaign_id=campaign or p.campaign_id is null)
 and p.channel=channel_key and p.currency=currency_key and p.product_revision_id is not distinct from product_revision
 and p.starts_at<=at_time and(p.ends_at is null or p.ends_at>at_time)
 order by(p.campaign_id is not null)desc,p.revision desc limit 1
$$;
create function boss_private.fundraising_allocation_command(command jsonb)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare actor uuid;action text;i jsonb;request uuid;campaign uuid;org uuid;team uuid;unit uuid;
 c public.fundraising_campaigns;p public.fundraising_platform_policies;r public.settlement_policy_revisions;pr public.discount_product_revisions;
 prior boss_private.fundraising_allocation_requests;id uuid;revision bigint;result jsonb;delegation public.fundraising_allocation_delegations;
begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);
 action:=command->>'action';i:=command->'input';request:=boss_private.athlete_uuid(command,'request_id');
 if action not in('brand.create','origin.bind','platform_policy.create','allocation_policy.create','delegation.create','delegation.revoke','wallet_channel.bind')then raise exception'Unknown allocation operation'using errcode='PT422';end if;
 campaign:=nullif(i->>'campaign_id','')::uuid;select *into c from public.fundraising_campaigns where id=campaign;
 org:=coalesce(c.organization_id,(i->>'organization_id')::uuid);team:=(i->>'team_id')::uuid;unit:=(i->>'unit_id')::uuid;
 if c.id is not null then perform 1 from public.fundraising_campaigns where id=c.id for update;end if;
 if action in('brand.create','origin.bind','platform_policy.create')then
  perform 1 from public.role_assignments where person_id=actor order by id for share;
  if not boss_private.fundraising_platform_actor(actor)then raise exception'Platform policy authority required'using errcode='PT403';end if;
 else
  if c.id is null then raise exception'Campaign unavailable'using errcode='PT403';end if;
  perform 1 from public.fundraising_campaigns where id=c.id for update;
  perform boss_private.fundraising_fence(org,actor);
  perform 1 from public.fundraising_allocation_delegations where campaign_id=c.id and person_id=actor order by id for share;
  if not boss_private.fundraising_allocation_manage(actor,c.id,team,unit)then raise exception'Exact allocation authority required'using errcode='PT403';end if;
 end if;
 perform boss_private.games_require_live_auth();
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-allocation-request:'||request,0));
 select *into prior from boss_private.fundraising_allocation_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command<>command then raise exception'Allocation replay conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true}';end if;
 if action='brand.create'then
  perform boss_private.athlete_input(i,array['key','name'],array['key','name']);
  insert into public.fundraising_brands(key,name,created_by)values(i->>'key',i->>'name',actor)returning fundraising_brands.id into id;
 elsif action='origin.bind'then
  perform boss_private.athlete_input(i,array['campaign_id','brand_id','fund_code'],array['campaign_id','brand_id','fund_code']);
  if c.id is null then raise exception'Campaign unavailable'using errcode='PT403';end if;
  perform 1 from public.fundraising_campaigns where id=c.id for update;
  if exists(select 1 from public.fundraising_intents where campaign_id=c.id)or exists(select 1 from public.discount_orders where campaign_id=c.id)then raise exception'Origin must precede financial activity'using errcode='PT409';end if;
  insert into public.fundraising_campaign_origins(campaign_id,organization_id,brand_id,legal_recipient_organization_id,fund_code,created_by)
  values(c.id,org,(i->>'brand_id')::uuid,org,i->>'fund_code',actor);id:=c.id;
 elsif action='platform_policy.create'then
  perform boss_private.athlete_input(i,array['organization_id','campaign_id','channel','currency','settlement_policy_id','product_revision_id','agreement_reference','exception_reference','participant_credit_max_bps','wallet_permitted','starts_at','ends_at'],array['organization_id','channel','currency','settlement_policy_id','agreement_reference','participant_credit_max_bps','wallet_permitted','starts_at']);
  if org is distinct from (i->>'organization_id')::uuid then raise exception'Exact policy tenant required'using errcode='PT403';end if;
  select *into r from public.settlement_policy_revisions where settlement_policy_revisions.id=(i->>'settlement_policy_id')::uuid;
  if r.organization_id is distinct from org or r.currency is distinct from i->>'currency'or r.purpose is distinct from(case when i->>'channel'in('digital_card','physical_card')then'products'else'fundraising'end)then raise exception'Exact settlement policy required'using errcode='PT422';end if;
  if i->>'product_revision_id'is not null then
   select *into pr from public.discount_product_revisions where discount_product_revisions.id=(i->>'product_revision_id')::uuid;
   if pr.organization_id is distinct from org or pr.currency is distinct from r.currency or pr.settlement_policy_id is distinct from r.id
    or not exists(select 1 from public.discount_products where discount_products.id=pr.product_id and kind=case i->>'channel'when'digital_card'then'digital'when'physical_card'then'physical'end)then raise exception'Exact card economics required'using errcode='PT422';end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-platform-policy:'||org,0));
  select coalesce(max(pp.revision),0)+1 into revision from public.fundraising_platform_policies pp where pp.organization_id=org and pp.campaign_id is not distinct from c.id and pp.channel=i->>'channel'and pp.currency=r.currency;
  insert into public.fundraising_platform_policies(organization_id,campaign_id,channel,currency,revision,settlement_policy_id,product_revision_id,agreement_reference,exception_reference,participant_credit_max_bps,wallet_permitted,starts_at,ends_at,created_by)
  values(org,c.id,i->>'channel',r.currency,revision,r.id,pr.id,i->>'agreement_reference',i->>'exception_reference',(i->>'participant_credit_max_bps')::int,(i->>'wallet_permitted')::boolean,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning fundraising_platform_policies.id into id;
 elsif action='allocation_policy.create'then
  perform boss_private.athlete_input(i,array['campaign_id','team_id','unit_id','channel','platform_policy_id','organization_bps','destination_bps','participant_bps','starts_at','ends_at'],array['campaign_id','channel','platform_policy_id','organization_bps','destination_bps','participant_bps','starts_at']);
  select *into p from public.fundraising_platform_policies where fundraising_platform_policies.id=(i->>'platform_policy_id')::uuid;
  if p.id is null or p.organization_id<>org or p.campaign_id is not null and p.campaign_id<>c.id or p.currency<>c.currency or p.channel<>i->>'channel'
   or (i->>'participant_bps')::int>p.participant_credit_max_bps or(i->>'starts_at')::timestamptz<p.starts_at
   or p.ends_at is not null and((i->>'ends_at')::timestamptz is null or(i->>'ends_at')::timestamptz>p.ends_at)then raise exception'Allocation exceeds platform envelope'using errcode='PT403';end if;
  select coalesce(max(ap.revision),0)+1 into revision from public.fundraising_allocation_policies ap where ap.campaign_id=c.id and ap.channel=p.channel and ap.team_id is not distinct from team and ap.unit_id is not distinct from unit;
  insert into public.fundraising_allocation_policies(organization_id,campaign_id,platform_policy_id,channel,team_id,unit_id,revision,organization_bps,destination_bps,participant_bps,starts_at,ends_at,created_by)
  values(org,c.id,p.id,p.channel,team,unit,revision,(i->>'organization_bps')::int,(i->>'destination_bps')::int,(i->>'participant_bps')::int,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning fundraising_allocation_policies.id into id;
 elsif action='delegation.create'then
  perform boss_private.athlete_input(i,array['campaign_id','person_id','team_id','unit_id','starts_at','ends_at'],array['campaign_id','person_id','starts_at','ends_at']);
  if not boss_private.fundraising_role(actor,'fundraising.manage',org)then raise exception'Organization delegation authority required'using errcode='PT403';end if;
  insert into public.fundraising_allocation_delegations(organization_id,campaign_id,person_id,team_id,unit_id,starts_at,ends_at,created_by)
  values(org,c.id,(i->>'person_id')::uuid,team,unit,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning fundraising_allocation_delegations.id into id;
 elsif action='delegation.revoke'then
  perform boss_private.athlete_input(i,array['campaign_id','delegation_id'],array['campaign_id','delegation_id']);
  if not boss_private.fundraising_role(actor,'fundraising.manage',org)then raise exception'Organization delegation authority required'using errcode='PT403';end if;
  select *into delegation from public.fundraising_allocation_delegations where fundraising_allocation_delegations.id=(i->>'delegation_id')::uuid and campaign_id=c.id for update;
  if delegation.id is null then raise exception'Exact delegation required'using errcode='PT403';end if;
  update public.fundraising_allocation_delegations set revoked_at=coalesce(revoked_at,clock_timestamp())where fundraising_allocation_delegations.id=delegation.id;id:=delegation.id;
 else
  perform boss_private.athlete_input(i,array['campaign_id','channel','wallet_policy_id','starts_at','ends_at'],array['campaign_id','channel','wallet_policy_id','starts_at']);
  if not boss_private.fundraising_role(actor,'fundraising.manage',org)or not exists(select 1 from public.boss_bucks_policy_revisions wp where wp.id=(i->>'wallet_policy_id')::uuid and wp.campaign_id=c.id and wp.currency=c.currency and i->>'channel'=any(wp.channels))then raise exception'Exact Wallet policy authority required'using errcode='PT403';end if;
  select coalesce(max(wc.revision),0)+1 into revision from public.fundraising_wallet_channel_policies wc where wc.campaign_id=c.id and wc.channel=i->>'channel';
  insert into public.fundraising_wallet_channel_policies(organization_id,campaign_id,channel,wallet_policy_id,revision,starts_at,ends_at,created_by)
  values(org,c.id,i->>'channel',(i->>'wallet_policy_id')::uuid,revision,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning fundraising_wallet_channel_policies.id into id;
 end if;
 result:=jsonb_build_object('id',id,'revision',revision,'action',action,'replayed',false);
 insert into boss_private.fundraising_allocation_requests(request_id,actor_id,command,result)values(request,actor,command,result);
 if c.id is not null then
  perform boss_private.fundraising_audit(actor,c.id,null,'fundraising.'||action,request,jsonb_build_object('id',id,'revision',revision));
 else
  insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,request_id,after_data)
  values(org,actor,auth.uid(),'fundraising.'||action,'fundraising_policy',id,request,jsonb_build_object('id',id,'revision',revision));
 end if;
 return result;
exception when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation then raise exception'Invalid allocation input'using errcode='PT422';when unique_violation then raise exception'Allocation revision conflict'using errcode='PT409';end$$;
create function public.boss_fundraising_allocation_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.fundraising_allocation_command(command)$$;
revoke all on function boss_private.fundraising_hamilton(bigint,bigint[]),boss_private.fundraising_allocation_manage(uuid,uuid,uuid,uuid),boss_private.fundraising_platform_policy(uuid,uuid,text,text,timestamptz,uuid),boss_private.fundraising_allocation_command(jsonb),public.boss_fundraising_allocation_mutate(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_private.fundraising_allocation_command(jsonb),public.boss_fundraising_allocation_mutate(jsonb)to authenticated;
