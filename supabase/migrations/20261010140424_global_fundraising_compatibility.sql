-- Local-only proposal. No economic rates, provider activation or historical rewrite.
-- Normalize only canonical source relationships; submitted channel labels are not authority.
create function boss_private.fundraising_channel(intent uuid) returns text
language plpgsql stable security definer set search_path='' as $$
declare i public.fundraising_intents; c public.fundraising_campaigns;
 p public.money_board_checkout_preparations; g public.money_board_groups; x public.money_board_carts;
begin
 select * into i from public.fundraising_intents where id=intent;
 select * into c from public.fundraising_campaigns where id=i.campaign_id;
 if c.id is null or i.currency<>c.currency
 or (i.provenance->>'organization_id')::uuid is distinct from c.organization_id
 or (i.provenance->>'campaign_id')::uuid is distinct from c.id
 or (i.provenance->>'currency') is distinct from i.currency
 or (i.provenance->>'amount_minor')::bigint is distinct from i.amount_minor
 or (i.fundraiser_id is not null and not exists(select 1 from public.fundraising_fundraisers f
  where f.id=i.fundraiser_id and f.campaign_id=c.id and f.organization_id=c.organization_id)) then return null; end if;
 select * into p from public.money_board_checkout_preparations where intent_id=i.id;
 if p.intent_id is not null then
  select * into g from public.money_board_groups where id=p.group_id;
  select * into x from public.money_board_carts where id=g.cart_id;
  if x.id is null or x.organization_id<>c.organization_id or x.campaign_id<>c.id
   or x.fundraiser_id is distinct from i.fundraiser_id or g.currency<>i.currency or g.amount_minor<>i.amount_minor
   or num_nonnulls(i.board_id,i.tile_id,i.reservation_id)<>0
   or i.provenance->>'channel' is distinct from 'money_board_group'
   or (i.provenance->>'board_id')::uuid is distinct from x.board_id
   or (i.provenance->>'group_id')::uuid is distinct from g.id
   or not exists(select 1 from public.money_board_group_items where group_id=g.id)
   or (select sum(amount_minor) from public.money_board_group_items where group_id=g.id)<>i.amount_minor
   or exists(select 1 from public.money_board_group_items l join public.money_board_tiles t on t.id=l.tile_id
     join public.money_board_reservations r on r.id=l.reservation_id where l.group_id=g.id
     and(t.board_id<>x.board_id or t.generation_id<>x.generation_id or t.amount_minor<>l.amount_minor or r.tile_id<>t.id))
  then return null; end if;
  return 'money_board';
 end if;
 if num_nonnulls(i.board_id,i.tile_id,i.reservation_id)=3 then
  if i.provenance->>'channel' is distinct from 'money_board' or not exists(
   select 1 from public.money_boards b join public.money_board_tiles t on t.board_id=b.id
   join public.money_board_reservations r on r.tile_id=t.id where b.id=i.board_id and b.campaign_id=c.id
   and t.id=i.tile_id and r.id=i.reservation_id and t.amount_minor=i.amount_minor)
  then return null; end if;
  return 'money_board';
 end if;
 if num_nonnulls(i.board_id,i.tile_id,i.reservation_id)=0
  and i.provenance->>'channel'='direct_support'
  and not (i.provenance ?| array['group_id','tile_id','board_id']) then return 'direct_support'; end if;
 return null;
exception when invalid_text_representation or numeric_value_out_of_range then return null;
end$$;
revoke all on function boss_private.fundraising_channel(uuid) from public,anon,authenticated,service_role,boss_payment_worker;
do $$declare d text;needle text:='case when x.board_id is null then''direct_support''else''money_board''end';begin
 d:=pg_get_functiondef('boss_private.bucks_issue(uuid)'::regprocedure);
 if position(needle in d)=0 then raise exception 'Wallet classification checkpoint mismatch';end if;
 d:=replace(d,'not('||needle||'=any(p.channels))','not(coalesce(boss_private.fundraising_channel(x.id)=any(p.channels),false))');execute d;
end$$;

insert into public.permissions(key,name,description) values
 ('fundraising.platform_policy_manage','Manage platform fundraising economics','Platform-only immutable revenue and approved allocation envelope');
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p
 where r.key in('super_administrator','platform_administrator') and p.key='fundraising.platform_policy_manage';
create function boss_private.fundraising_platform_actor(actor uuid) returns boolean
language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.people where id=actor and status='active') and exists(
 select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id
 where p.key='fundraising.platform_policy_manage' and p.status='active' and a.person_id=actor
 and a.scope_type='platform' and a.scope_id is null and a.organization_id is null
 and a.status='active' and a.starts_at<=clock_timestamp() and(a.ends_at is null or a.ends_at>clock_timestamp()))
$$;
alter function boss_private.rails_mutate(jsonb) rename to rails_mutate_before_global;
create function boss_private.rails_mutate(command jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;begin
 if command->>'action'='policy.create' then
  perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
  perform 1 from public.role_assignments where person_id=actor order by id for share;
  if not boss_private.fundraising_platform_actor(actor) then raise exception 'Platform policy authority required' using errcode='PT403';end if;
  -- Fixed fundraising charges are implemented by the native donation preparation contract.
  -- Fee bills, product prices and Wallet redemption retain their existing economics.
  if coalesce((command->'input'->>'platform_fee_minor')::bigint,0)>0
   and command->'input'->>'purpose' is distinct from 'fundraising' then
   raise exception 'Fixed charge is not supported by this checkout contract' using errcode='PT422';end if;
 end if;
 return boss_private.rails_mutate_before_global(command);
end$$;
revoke all on function boss_private.fundraising_platform_actor(uuid),boss_private.rails_mutate_before_global(jsonb),boss_private.rails_mutate(jsonb)
 from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_private.rails_mutate(jsonb) to authenticated;
do $$declare d text;needle text;begin
 d:=pg_get_functiondef('boss_private.rails_mutate_before_global(jsonb)'::regprocedure);
 needle:='''estimated_processor_flat_minor''],array[''organization_id'',''purpose''';
 if position(needle in d)=0 then raise exception'Platform fixed fee input checkpoint mismatch';end if;
 d:=replace(d,needle,'''estimated_processor_flat_minor'',''platform_fee_minor''],array[''organization_id'',''purpose''');
 d:=replace(d,'estimated_processor_flat_minor,created_by)','estimated_processor_flat_minor,platform_fee_minor,created_by)');
 d:=replace(d,'(i->>''estimated_processor_flat_minor'')::bigint,actor)','(i->>''estimated_processor_flat_minor'')::bigint,coalesce((i->>''platform_fee_minor'')::bigint,0),actor)');execute d;
end$$;
-- Preserve account/route management; only policy authorship is platform-controlled.
do $$declare d text;needle text:='''can_configure'',manager,';begin
 d:=pg_get_functiondef('boss_private.rails_read(jsonb)'::regprocedure);
 if position(needle in d)=0 then raise exception 'Payment read checkpoint mismatch';end if;
 execute replace(d,needle,needle||'''can_configure_policy'',boss_private.fundraising_platform_actor(actor),');
end$$;
