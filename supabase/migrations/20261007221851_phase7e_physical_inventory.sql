create table public.discount_card_batches(
 id uuid primary key default gen_random_uuid(),revision_id uuid not null references public.discount_product_revisions(id),
 organization_id uuid references public.organizations(id),campaign_id uuid,owner_type text not null check(owner_type in('platform','organization','campaign')),
 name text not null check(length(btrim(name))between 1 and 100),quantity integer not null check(quantity>0),
 status text not null default 'created'check(status in('created','printed','inventory','archived')),controlled boolean not null default false,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),printed_at timestamptz,
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 check(owner_type='platform'or organization_id is not null),check((owner_type='campaign')=(campaign_id is not null)));
create index discount_card_batches_org_idx on public.discount_card_batches(organization_id,created_at desc,id);
create index discount_card_batches_campaign_idx on public.discount_card_batches(campaign_id,id);
create index discount_card_batches_revision_idx on public.discount_card_batches(revision_id);
create index discount_card_batches_creator_idx on public.discount_card_batches(created_by);
create table public.discount_physical_cards(
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references public.discount_card_batches(id),ordinal integer not null check(ordinal>0),
 serial text not null unique default 'BBC-'||upper(replace(gen_random_uuid()::text,'-','')),
 organization_id uuid references public.organizations(id),campaign_id uuid,fundraiser_id uuid,
 state text not null default 'created'check(state in('created','printed','inventory','assigned','sold','claimed','active','replaced','void','expired')),
 membership_id uuid references public.discount_memberships(id),order_item_id uuid unique,
 printed_at timestamptz,sold_at timestamptz,claimed_at timestamptz,claimed_by uuid references public.people(id),
 replaced_by uuid unique references public.discount_physical_cards(id),version bigint not null default 1,
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 unique(batch_id,ordinal),foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(campaign_id,fundraiser_id)references public.fundraising_fundraisers(campaign_id,id),
 check((claimed_at is null)=(claimed_by is null)),check(claimed_at is null or membership_id is not null),check(replaced_by is null or state='replaced'));
create index discount_cards_inventory_idx on public.discount_physical_cards(organization_id,state,id);
create index discount_cards_campaign_idx on public.discount_physical_cards(campaign_id,state,id);
create index discount_cards_fundraiser_idx on public.discount_physical_cards(fundraiser_id,state,id);
create index discount_cards_member_idx on public.discount_physical_cards(membership_id,id);
create index discount_cards_actor_idx on public.discount_physical_cards(claimed_by);
create table boss_private.discount_card_secrets(
 card_id uuid primary key references public.discount_physical_cards(id),digest text not null unique check(digest~'^[a-f0-9]{64}$'),
 revoked_at timestamptz,created_at timestamptz not null default clock_timestamp());
create table public.discount_card_history(
 id uuid primary key default gen_random_uuid(),card_id uuid not null references public.discount_physical_cards(id),actor_id uuid references public.people(id),
 action text not null check(action in('created','printed','assigned','returned','allocated','claimed','replaced','void','expired')),
 source_id uuid,organization_id uuid references public.organizations(id),campaign_id uuid references public.fundraising_campaigns(id),fundraiser_id uuid references public.fundraising_fundraisers(id),
 created_at timestamptz not null default clock_timestamp());
create index discount_card_history_card_idx on public.discount_card_history(card_id,created_at,id);
create index discount_card_history_actor_idx on public.discount_card_history(actor_id);
create index discount_card_history_org_idx on public.discount_card_history(organization_id,created_at,id);
create index discount_card_history_campaign_idx on public.discount_card_history(campaign_id);
create index discount_card_history_fundraiser_idx on public.discount_card_history(fundraiser_id);
create function boss_private.discount_card_valid(card uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.discount_physical_cards c join public.discount_card_batches b on b.id=c.batch_id
 join public.discount_product_revisions r on r.id=b.revision_id where c.id=card and c.state not in('void','replaced','expired')and b.status<>'archived'
 and case r.validity_anchor when'print'then coalesce(c.printed_at,b.printed_at)when'sale'then c.sold_at when'activation'then coalesce(c.claimed_at,clock_timestamp())end is not null
 and case r.validity_anchor when'print'then coalesce(c.printed_at,b.printed_at)when'sale'then c.sold_at when'activation'then coalesce(c.claimed_at,clock_timestamp())end+make_interval(days=>r.card_validity_days)>clock_timestamp())
$$;
create function boss_private.discount_batch_create(actor uuid,input jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare r public.discount_product_revisions;b public.discount_card_batches;c public.discount_physical_cards;secret text;secrets jsonb:='[]';n integer;org uuid;camp uuid;owner text;begin
 perform boss_private.athlete_input(input,array['revision_id','organization_id','campaign_id','owner_type','name','quantity','controlled'],array['revision_id','owner_type','name','quantity','controlled']);
 org:=(input->>'organization_id')::uuid;camp:=(input->>'campaign_id')::uuid;owner:=input->>'owner_type';n:=(input->>'quantity')::integer;
 perform boss_private.discount_fence(actor,org);
 select *into r from public.discount_product_revisions where id=(input->>'revision_id')::uuid for share;
 if not boss_private.rails_actor_current(actor)or not(case when owner='platform'then boss_private.discount_platform(actor)else boss_private.discount_role(actor,'boss_bucks.inventory_manage',org)end)
 or org is not null and not boss_private.discount_feature(org,'physical_cards')then raise exception'Inventory access denied'using errcode='PT403';end if;
 if r.id is null or not boss_private.discount_revision_active(r.id)or not exists(select 1 from public.discount_products where id=r.product_id and kind='physical')
 or r.validity_anchor is null or r.trial_days is null or r.organization_id is not null and r.organization_id is distinct from org
 or n not between 1 and 1000 or owner not in('platform','organization','campaign')or owner<>'platform'and org is null
 or (owner='campaign')is distinct from(camp is not null)or camp is not null and not exists(select 1 from public.fundraising_campaigns where id=camp and organization_id=org)
 or length(btrim(input->>'name'))not between 1 and 100 or jsonb_typeof(input->'controlled')is distinct from'boolean'then raise exception'Review the physical batch fields'using errcode='PT422';end if;
 insert into public.discount_card_batches(revision_id,organization_id,campaign_id,owner_type,name,quantity,controlled,created_by)
 values(r.id,org,camp,owner,input->>'name',n,(input->>'controlled')::boolean,actor)returning *into b;
 for ordinal in 1..n loop
 insert into public.discount_physical_cards(batch_id,ordinal,organization_id,campaign_id)values(b.id,ordinal,org,camp)returning *into c;
 secret:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');insert into boss_private.discount_card_secrets(card_id,digest)values(c.id,encode(sha256(convert_to(secret,'UTF8')),'hex'));
 secrets:=secrets||jsonb_build_array(jsonb_build_object('card_id',c.id,'serial',c.serial,'activation_secret',secret));
 insert into public.discount_card_history(card_id,actor_id,action,organization_id,campaign_id)values(c.id,actor,'created',org,camp);
 end loop;
 perform boss_private.discount_audit(actor,org,null,'card.batch.created',b.id,request,jsonb_build_object('quantity',n,'controlled',b.controlled,'one_time_export',true));
 return jsonb_build_object('batch_id',b.id,'quantity',n,'one_time_cards',secrets);
end$$;
create function boss_private.discount_cards_update(actor uuid,action text,input jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare card uuid;c public.discount_physical_cards;b public.discount_card_batches;f public.fundraising_fundraisers;org uuid;camp uuid;fundraiser uuid;count integer:=0;begin
 perform boss_private.athlete_input(input,array['organization_id','campaign_id','fundraiser_id','card_ids'],array['organization_id','card_ids']);
 org:=(input->>'organization_id')::uuid;camp:=(input->>'campaign_id')::uuid;fundraiser:=(input->>'fundraiser_id')::uuid;
 if jsonb_typeof(input->'card_ids')is distinct from'array'or jsonb_array_length(input->'card_ids')not between 1 and 1000
 or(select count(distinct value)from jsonb_array_elements_text(input->'card_ids'))<>jsonb_array_length(input->'card_ids')then raise exception'Bounded distinct cards required'using errcode='PT422';end if;
 if camp is not null then perform 1 from public.fundraising_campaigns where id=camp and organization_id=org for update;end if;
 if fundraiser is not null then select *into f from public.fundraising_fundraisers where id=fundraiser and organization_id=org and campaign_id=camp for update;end if;
 perform boss_private.discount_fence(actor,org);
 if not boss_private.discount_feature(org,'physical_cards')or not boss_private.discount_role(actor,'boss_bucks.inventory_manage',org)
 and not(camp is not null and boss_private.fundraising_role(actor,'fundraising.manage',org,f.unit_id,f.team_id))then raise exception'Inventory scope denied'using errcode='PT403';end if;
 if action not in('cards.assign','cards.return','cards.print','cards.void')or camp is not null and not exists(select 1 from public.fundraising_campaigns where id=camp and organization_id=org)
 or fundraiser is not null and(f.id is null or not boss_private.fundraising_member(f))then raise exception'Exact active inventory target required'using errcode='PT422';end if;
 for card in select value::uuid from jsonb_array_elements_text(input->'card_ids')order by value loop
 select *into c from public.discount_physical_cards where id=card for update;select *into b from public.discount_card_batches where id=c.batch_id;
 if c.id is null or c.organization_id is distinct from org and not(c.organization_id is null and b.owner_type='platform'and boss_private.discount_platform(actor)and action in('cards.assign','cards.print','cards.void')and exists(select 1 from public.discount_product_revisions r where r.id=b.revision_id and(r.organization_id is null or r.organization_id=org)))or b.status='archived'or b.campaign_id is not null and b.campaign_id is distinct from camp
 or not boss_private.discount_role(actor,'boss_bucks.inventory_manage',org)and(c.campaign_id is distinct from camp or c.fundraiser_id is distinct from fundraiser)
 then raise exception'Inventory scope denied'using errcode='PT403';end if;
 if action='cards.assign'then
 if c.state not in('printed','inventory')or c.order_item_id is not null or camp is null then raise exception'Card is already allocated or unavailable'using errcode='PT409';end if;
 update public.discount_physical_cards set state='assigned',organization_id=org,campaign_id=camp,fundraiser_id=fundraiser,version=version+1,updated_at=clock_timestamp()where id=c.id;
 elsif action='cards.return'then
 if c.state<>'assigned'or c.order_item_id is not null then raise exception'Only unsold assignment may return'using errcode='PT409';end if;
 update public.discount_physical_cards set state='inventory',organization_id=b.organization_id,campaign_id=b.campaign_id,fundraiser_id=null,version=version+1,updated_at=clock_timestamp()where id=c.id;
 elsif action='cards.print'then
 if c.state<>'created'then raise exception'Card print state changed'using errcode='PT409';end if;
 update public.discount_physical_cards set state='inventory',printed_at=clock_timestamp(),version=version+1,updated_at=clock_timestamp()where id=c.id;
 update public.discount_card_batches set status='inventory',printed_at=coalesce(printed_at,clock_timestamp())where id=b.id;
 else
 if c.order_item_id is not null then raise exception'Purchased card requires its original order correction'using errcode='PT409';end if;
 if c.state in('void','replaced')then continue;end if;
 update public.discount_physical_cards set state='void',version=version+1,updated_at=clock_timestamp()where id=c.id;
 update boss_private.discount_card_secrets set revoked_at=clock_timestamp()where card_id=c.id;
 if c.membership_id is not null then for card in select id from public.discount_member_sources where source_key in(with recursive lineage as(select id from public.discount_physical_cards where id=c.id union all select p.id from public.discount_physical_cards p join lineage l on p.replaced_by=l.id)select 'card-trial:'||id from lineage)loop perform boss_private.discount_revoke(card,'revoked',c.id,actor);end loop;end if;
 end if;
 insert into public.discount_card_history(card_id,actor_id,action,organization_id,campaign_id,fundraiser_id)
 values(c.id,actor,case action when'cards.assign'then'assigned'when'cards.return'then'returned'when'cards.print'then'printed'else'void'end,org,camp,fundraiser);count:=count+1;
 end loop;
 perform boss_private.discount_audit(actor,org,null,'card.'||split_part(action,'.',2),org,request,jsonb_build_object('count',count));return jsonb_build_object('count',count);
end$$;
create function boss_private.discount_card_claim(actor uuid,serial text,secret text,household uuid default null)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare c public.discount_physical_cards;r public.discount_product_revisions;b public.discount_card_batches;subject uuid;member uuid;existing uuid;claimed timestamptz;begin
 if coalesce(serial,'')!~'^BBC-[A-F0-9]{32}$'or coalesce(secret,'')!~'^[a-f0-9]{64}$'then raise exception'Card unavailable'using errcode='PT404';end if;
 select *into c from public.discount_physical_cards where discount_physical_cards.serial=discount_card_claim.serial;
 perform boss_private.discount_fence(actor,c.organization_id,household);
 select *into c from public.discount_physical_cards where id=c.id for update;
 if c.id is null or not exists(select 1 from boss_private.discount_card_secrets s where s.card_id=c.id and s.revoked_at is null
 and s.digest=encode(sha256(convert_to(secret,'UTF8')),'hex'))or not boss_private.discount_feature(c.organization_id,'physical_cards')or not boss_private.discount_feature(c.organization_id,'discount_membership')then raise exception'Card unavailable'using errcode='PT404';end if;
 if c.claimed_by is not null then if c.claimed_by=actor and c.state in('claimed','active')then return c.membership_id;end if;raise exception'Card unavailable'using errcode='PT404';end if;
 select *into b from public.discount_card_batches where id=c.batch_id;select *into r from public.discount_product_revisions where id=b.revision_id;
 subject:=case r.subject_type when'person'then actor else household end;
 if c.state not in('inventory','assigned','sold')or not boss_private.discount_card_valid(c.id)or not boss_private.discount_subject(actor,r.subject_type,subject,true)
 or r.trial_days is null then raise exception'Card unavailable'using errcode='PT404';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-discount-subject:'||r.membership_product_id||':'||r.subject_type||':'||subject||':'||r.country||':'||r.region||':'||r.market,0));
 select id into existing from public.discount_memberships where product_id=r.membership_product_id and subject_type=r.subject_type and subject_id=subject and country=r.country and region=r.region and market=r.market;
 if existing is not null and exists(select 1 from public.discount_member_sources s where membership_id=existing and kind in('fundraising_trial','physical_card_digital_trial')
 and starts_at<=clock_timestamp()and ends_at>clock_timestamp()and not exists(select 1 from public.discount_source_revocations v where v.source_id=s.id))then member:=existing;
 else claimed:=clock_timestamp();member:=boss_private.discount_issue(r.id,'physical_card_digital_trial','card-trial:'||c.id,c.organization_id,c.campaign_id,c.fundraiser_id,null,null,null,subject,claimed,claimed+make_interval(days=>r.trial_days));end if;
 update public.discount_physical_cards set state='active',membership_id=member,claimed_by=actor,claimed_at=coalesce(claimed,clock_timestamp()),updated_at=clock_timestamp(),version=version+1 where id=c.id;
 insert into public.discount_card_history(card_id,actor_id,action,source_id,organization_id,campaign_id,fundraiser_id)values(c.id,actor,'claimed',member,c.organization_id,c.campaign_id,c.fundraiser_id);
 perform boss_private.discount_audit(actor,c.organization_id,member,'card.claimed',c.id,null,jsonb_build_object('trial_days',r.trial_days,'trial_starts_on_claim',true,'existing_trial_preserved',member=existing));return member;
end$$;
create function boss_private.discount_card_replace(actor uuid,input jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare oldcard public.discount_physical_cards;replacement public.discount_physical_cards;reason text;begin
 perform boss_private.athlete_input(input,array['card_id','replacement_card_id','reason'],array['card_id','replacement_card_id','reason']);reason:=input->>'reason';
 select *into oldcard from public.discount_physical_cards where id=(input->>'card_id')::uuid;
 perform boss_private.discount_fence(actor,oldcard.organization_id);
 if not boss_private.discount_role(actor,'boss_bucks.inventory_manage',oldcard.organization_id)or not boss_private.discount_feature(oldcard.organization_id,'physical_cards')then raise exception'Card replacement denied'using errcode='PT403';end if;
 perform 1 from public.discount_physical_cards where id in(oldcard.id,(input->>'replacement_card_id')::uuid)order by id for update;
 select *into oldcard from public.discount_physical_cards where id=oldcard.id;select *into replacement from public.discount_physical_cards where id=(input->>'replacement_card_id')::uuid;
 if oldcard.id is null or replacement.id is null or oldcard.id=replacement.id or oldcard.state not in('active','claimed')or replacement.state not in('inventory','printed')
 or replacement.organization_id is distinct from oldcard.organization_id or replacement.order_item_id is not null or reason not in('lost','damaged','compromised')
 or(select revision_id from public.discount_card_batches where id=oldcard.batch_id)is distinct from(select revision_id from public.discount_card_batches where id=replacement.batch_id)
 then raise exception'Eligible same-product replacement required'using errcode='PT409';end if;
 update public.discount_physical_cards set state='active',membership_id=oldcard.membership_id,claimed_at=oldcard.claimed_at,claimed_by=oldcard.claimed_by,sold_at=oldcard.sold_at,
 campaign_id=oldcard.campaign_id,fundraiser_id=oldcard.fundraiser_id,updated_at=clock_timestamp(),version=version+1 where id=replacement.id;
 update public.discount_physical_cards set state='replaced',replaced_by=replacement.id,updated_at=clock_timestamp(),version=version+1 where id=oldcard.id;
 update boss_private.discount_card_secrets set revoked_at=clock_timestamp()where card_id=oldcard.id;
 insert into public.discount_card_history(card_id,actor_id,action,source_id,organization_id)values(oldcard.id,actor,'replaced',replacement.id,oldcard.organization_id);
 perform boss_private.discount_audit(actor,oldcard.organization_id,oldcard.membership_id,'card.replaced',oldcard.id,request,jsonb_build_object('replacement_id',replacement.id,'reason',reason));
 return jsonb_build_object('card_id',replacement.id,'membership_id',oldcard.membership_id);
end$$;
do $$declare t text;p record;begin
foreach t in array array['discount_card_batches','discount_physical_cards','discount_card_history']loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);end loop;
alter table boss_private.discount_card_secrets enable row level security;revoke all on boss_private.discount_card_secrets from public,anon,authenticated,service_role,boss_payment_worker;
for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'discount_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;
