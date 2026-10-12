-- Bind complete destination metadata to the cart, not just its public path.
create function boss_private.money_board_context(path text)returns jsonb language plpgsql volatile security definer set search_path=''as $$
 declare ctx jsonb;f public.fundraising_fundraisers;c public.fundraising_campaigns;b public.money_boards;begin
 ctx:=boss_private.fundraising_public_context(path);select *into f from public.fundraising_fundraisers where id=(ctx->>'fundraiser_id')::uuid;select *into c from public.fundraising_campaigns where id=(ctx->>'campaign_id')::uuid;select *into b from public.money_boards where id=(ctx->>'board_id')::uuid;
 return jsonb_strip_nulls(ctx||jsonb_build_object('organization_id',c.organization_id,'currency',c.currency,'participant_id',f.participant_id,'unit_id',f.unit_id,'household_id',f.household_id,'team_id',coalesce(f.team_id,b.team_id)));end$$;
create function boss_private.money_board_provenance(cart uuid)returns jsonb language sql stable security definer set search_path=''as $$
 select x.context||jsonb_build_object('organization_id',x.organization_id,'campaign_id',x.campaign_id,'board_id',x.board_id,'generation_id',x.generation_id,'fundraiser_id',x.fundraiser_id,'participant_id',f.participant_id,'person_id',f.person_id,'unit_id',f.unit_id,'team_id',coalesce(f.team_id,b.team_id),'household_id',f.household_id,'currency',x.currency,'policy_revision',x.policy_revision)
 from public.money_board_carts x join public.money_boards b on b.id=x.board_id left join public.fundraising_fundraisers f on f.id=x.fundraiser_id where x.id=cart
$$;
create function boss_private.money_board_cart_fence(cart uuid,path text,require_session boolean default true)returns public.money_board_carts language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare x public.money_board_carts;ctx jsonb;begin
 select *into x from public.money_board_carts where id=cart;
 if x.id is null or x.path_digest<>encode(sha256(convert_to(path,'UTF8')),'hex')or require_session and x.expires_at<=clock_timestamp()then raise exception'Cart unavailable or expired'using errcode='PT404';end if;
 perform 1 from public.fundraising_campaigns where id=x.campaign_id for update;
 if x.fundraiser_id is not null then perform 1 from public.fundraising_fundraisers where id=x.fundraiser_id for update;end if;
 perform boss_private.fundraising_fence(x.organization_id,(x.context->>'authorized_by')::uuid,(x.context->>'person_id')::uuid);
 ctx:=boss_private.money_board_context(path);
 if ctx is distinct from x.context then raise exception'Cart scope changed'using errcode='PT409';end if;
 if x.actor_person_id is not null then
 perform boss_private.games_require_live_auth();
 if x.actor_person_id is distinct from boss_private.current_person_id()then raise exception'Cart account changed'using errcode='PT403';end if;end if;
 perform 1 from public.money_boards where id=x.board_id for update;
 if x.generation_id is distinct from(select id from public.money_board_generations where board_id=x.board_id order by generation desc limit 1)then raise exception'Board generation changed'using errcode='PT409';end if;
 perform 1 from public.money_board_carts where id=x.id for update;
 return x;
end$$;
create function boss_private.money_board_group_state(group_id uuid)returns text language sql volatile security definer set search_path=''as $$
 select case
 when exists(select 1 from public.money_board_checkout_preparations p join public.fundraising_success_evidence e on e.intent_id=p.intent_id where p.group_id=g.id)then'confirmed'
 when exists(select 1 from public.money_board_checkout_preparations p join public.payment_checkouts c on c.intent_id=p.intent_id where p.group_id=g.id and c.state<>'ready'and boss_private.rails_hold(c.id))then'payment_pending'
 when exists(select 1 from public.money_board_checkout_preparations p join public.payment_checkouts c on c.intent_id=p.intent_id where p.group_id=g.id and c.state='failed')then'failed'
 when exists(select 1 from public.money_board_checkout_preparations p join public.payment_checkouts c on c.intent_id=p.intent_id where p.group_id=g.id and c.state='canceled')then'canceled'
 when exists(select 1 from public.money_board_group_items l join public.money_board_reservations r on r.id=l.reservation_id where l.group_id=g.id and r.released_at is not null)then case when exists(select 1 from public.money_board_group_items l join public.money_board_reservations r on r.id=l.reservation_id where l.group_id=g.id and r.release_reason='expired')then'expired'else'canceled'end
 when g.expires_at<=clock_timestamp()then'expired'
 when exists(select 1 from public.money_board_checkout_preparations where group_id=g.id)then'awaiting_payment'
 else'reserved'end from public.money_board_groups g where g.id=group_id
$$;
create function boss_private.money_board_cart_projection(cart uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare x public.money_board_carts;p public.money_board_cart_policies;g public.money_board_groups;items jsonb;state text;begin
 select *into x from public.money_board_carts where id=cart;select *into p from public.money_board_cart_policies where revision=x.policy_revision;
 select *into g from public.money_board_groups where cart_id=cart order by starts_at desc,id desc limit 1;
 state:=coalesce(boss_private.money_board_group_state(g.id),'selection');
 select coalesce(jsonb_agg(jsonb_build_object('tile_id',t.id,'ordinal',t.ordinal,'amount_minor',i.amount_minor,'available',boss_private.money_board_tile_available(t.id))order by t.ordinal),'[]')into items
 from public.money_board_cart_items i join public.money_board_tiles t on t.id=i.tile_id where i.cart_id=x.id and i.removed_at is null;
 return jsonb_build_object('version',1,'state',state,'currency',x.currency,'items',items,'subtotal_minor',coalesce((select sum(amount_minor)from public.money_board_cart_items where cart_id=x.id and removed_at is null),0),
 'max_tiles',p.max_tiles,'max_total_minor',p.max_total_minor,'session_expires_at',x.expires_at,'reservation_expires_at',g.expires_at,'payment_available',false);
end$$;
create function boss_private.money_board_end_group(gid uuid,reason text)returns void language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare state text;i uuid;begin
 state:=boss_private.money_board_group_state(gid);
 if state in('payment_pending','confirmed')then raise exception'Original payment outcome must be resolved'using errcode='PT409';end if;
 perform 1 from public.money_board_tiles t join public.money_board_group_items l on l.tile_id=t.id where l.group_id=gid order by t.id for update of t;
 update public.money_board_reservations r set released_at=clock_timestamp(),release_reason=reason from public.money_board_group_items l where l.group_id=gid and l.reservation_id=r.id and r.released_at is null;
 select intent_id into i from public.money_board_checkout_preparations where group_id=gid;
 if i is not null and not exists(select 1 from public.fundraising_intent_events where intent_id=i and state<>'awaiting_payment')then insert into public.fundraising_intent_events(intent_id,state)values(i,'failed');end if;
end$$;
create function boss_private.money_board_cart_command(command jsonb,session_capability text)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare a text;i jsonb;request uuid;cap text;h text;ctx jsonb;x public.money_board_carts;c public.fundraising_campaigns;b public.money_boards;g public.money_board_groups;p public.money_board_cart_policies;
 receipt boss_private.money_board_cart_receipts;t public.money_board_tiles;line record;result jsonb;total bigint;at_time timestamptz;rid uuid;donor uuid;intent uuid;actor uuid;subcap text;attribution text;active_state text;
begin
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);a:=command->>'action';i:=command->'input';request:=boss_private.athlete_uuid(command,'request_id');
 perform boss_private.athlete_input(i,case a when'add'then array['path','tile_id']when'remove'then array['path','tile_id']when'prepare'then array['path','display_name','email','mobile','anonymous','fee_cover','source']else array['path']end,array['path']);
 if a not in('open','read','recover','revalidate','add','remove','clear','reserve','cancel','expire','prepare')or session_capability is null or session_capability!~'^[a-f0-9]{64}$'then raise exception'Invalid cart request'using errcode='PT422';end if;
 cap:=encode(sha256(convert_to(session_capability,'UTF8')),'hex');h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');
 select *into x from public.money_board_carts where capability_digest=cap;
 if x.id is null then
 if a<>'open'then raise exception'Cart unavailable'using errcode='PT404';end if;
 ctx:=boss_private.money_board_context(i->>'path');
 select *into c from public.fundraising_campaigns where id=(ctx->>'campaign_id')::uuid for update;
 if ctx?'fundraiser_id'then perform 1 from public.fundraising_fundraisers where id=(ctx->>'fundraiser_id')::uuid for update;end if;
 perform boss_private.fundraising_fence(c.organization_id,(ctx->>'authorized_by')::uuid,(ctx->>'person_id')::uuid);
 ctx:=boss_private.money_board_context(i->>'path');
 select *into b from public.money_boards where id=(ctx->>'board_id')::uuid for update;
 if b.id is null then raise exception'Board unavailable'using errcode='PT404';end if;
 if auth.uid()is not null then perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();end if;
 select *into p from public.money_board_cart_policies order by revision desc limit 1;
 perform pg_advisory_xact_lock(hashtextextended('money-board-session:'||cap,0));
 select *into x from public.money_board_carts where capability_digest=cap;
 if x.id is null then insert into public.money_board_carts(organization_id,campaign_id,board_id,generation_id,fundraiser_id,path_digest,capability_digest,actor_person_id,currency,context,policy_revision,expires_at)
 values(c.organization_id,c.id,b.id,(select id from public.money_board_generations where board_id=b.id order by generation desc limit 1),(ctx->>'fundraiser_id')::uuid,
 encode(sha256(convert_to(i->>'path','UTF8')),'hex'),cap,actor,c.currency,ctx,p.revision,clock_timestamp()+make_interval(secs=>p.session_seconds))returning *into x;end if;
 end if;
 x:=boss_private.money_board_cart_fence(x.id,i->>'path');
 perform pg_advisory_xact_lock(hashtextextended('money-board-cart-request:'||request,0));
 select *into receipt from boss_private.money_board_cart_receipts where request_id=request;
 if receipt.request_id is not null then if receipt.cart_id<>x.id or receipt.input_hash<>h then raise exception'Cart replay conflict'using errcode='PT409';end if;
 return boss_private.money_board_cart_projection(x.id)||jsonb_build_object('action',a,'replayed',true);end if;
 perform boss_private.rails_rate('money-board-cart:'||x.id,120);
 select *into p from public.money_board_cart_policies where revision=x.policy_revision;
 select *into g from public.money_board_groups where cart_id=x.id order by starts_at desc,id desc limit 1;active_state:=boss_private.money_board_group_state(g.id);
 if active_state in('expired','failed','canceled')then perform boss_private.money_board_end_group(g.id,case active_state when'expired'then'expired'else'supporter_cancel'end);end if;
 if a in('add','remove','clear','reserve')and active_state in('reserved','awaiting_payment','payment_pending','confirmed')then raise exception'End the original group before editing the cart'using errcode='PT409';end if;
 if a='add'then
 select *into t from public.money_board_tiles where id=(i->>'tile_id')::uuid and board_id=x.board_id and generation_id=x.generation_id for update;
 if t.id is null then raise exception'Tile outside this board generation'using errcode='PT404';end if;
 if not boss_private.money_board_tile_available(t.id)then raise exception'Tile availability changed'using errcode='PT409';end if;
 if not exists(select 1 from public.money_board_cart_items where cart_id=x.id and tile_id=t.id and removed_at is null)then
 select coalesce(sum(amount_minor),0)into total from public.money_board_cart_items where cart_id=x.id and removed_at is null;
 if (select count(*)from public.money_board_cart_items where cart_id=x.id and removed_at is null)>=p.max_tiles or total+t.amount_minor>p.max_total_minor then raise exception'Cart exceeds configured count or amount policy'using errcode='PT422';end if;
 insert into public.money_board_cart_items(cart_id,tile_id,amount_minor,provenance)values(x.id,t.id,t.amount_minor,boss_private.money_board_provenance(x.id)||jsonb_build_object('generation_id',x.generation_id,'tile_id',t.id,'organization_id',x.organization_id,'currency',x.currency,'policy_revision',p.revision))
 on conflict(cart_id,tile_id)do update set removed_at=null;end if;
 elsif a='remove'then update public.money_board_cart_items set removed_at=clock_timestamp()where cart_id=x.id and tile_id=(i->>'tile_id')::uuid and removed_at is null;
 elsif a='clear'then update public.money_board_cart_items set removed_at=clock_timestamp()where cart_id=x.id and removed_at is null;
 elsif a in('cancel','expire')then
 if g.id is not null then
 if a='expire'and g.expires_at>clock_timestamp()then raise exception'Reservation has not expired'using errcode='PT409';end if;
 perform boss_private.money_board_end_group(g.id,case a when'expire'then'expired'else'supporter_cancel'end);end if;
 elsif a='reserve'then
 select coalesce(sum(amount_minor),0)into total from public.money_board_cart_items where cart_id=x.id and removed_at is null;
 if total<1 or total>p.max_total_minor or(select count(*)from public.money_board_cart_items where cart_id=x.id and removed_at is null)>p.max_tiles then raise exception'Empty or oversized cart'using errcode='PT422';end if;
 perform 1 from public.money_board_tiles t join public.money_board_cart_items l on l.tile_id=t.id where l.cart_id=x.id and l.removed_at is null order by t.id for update of t;
 if exists(select 1 from public.money_board_cart_items l join public.money_board_tiles t on t.id=l.tile_id where l.cart_id=x.id and l.removed_at is null and(t.board_id<>x.board_id or t.generation_id<>x.generation_id or t.amount_minor<>l.amount_minor or not boss_private.money_board_tile_available(t.id)))then raise exception'Group conflict; no tiles reserved'using errcode='PT409';end if;
 select *into b from public.money_boards where id=x.board_id;at_time:=clock_timestamp();
 insert into public.money_board_groups(cart_id,request_id,amount_minor,currency,policy_revision,starts_at,expires_at)values(x.id,request,total,x.currency,p.revision,at_time,at_time+make_interval(secs=>b.reservation_seconds))returning *into g;
 for line in select *from public.money_board_cart_items where cart_id=x.id and removed_at is null order by tile_id loop
 insert into public.money_board_reservations(tile_id,capability_digest,starts_at,expires_at,request_id)
 values(line.tile_id,encode(sha256(convert_to(cap||':'||g.id||':'||line.tile_id,'UTF8')),'hex'),g.starts_at,g.expires_at,gen_random_uuid())returning id into rid;
 insert into public.money_board_group_items(group_id,tile_id,reservation_id,amount_minor,provenance)values(g.id,line.tile_id,rid,line.amount_minor,line.provenance);end loop;
 elsif a='prepare'then
 if g.id is null or active_state not in('reserved','awaiting_payment')then raise exception'Active group reservation required'using errcode='PT409';end if;
 if exists(select 1 from public.money_board_checkout_preparations where group_id=g.id)then raise exception'Use the original prepared checkout'using errcode='PT409';end if;
 if length(btrim(i->>'display_name'))not between 1 and 100 or i->>'display_name'is null or length(coalesce(i->>'email',''))>254 or length(coalesce(i->>'mobile',''))>32 then raise exception'Invalid supporter details'using errcode='PT422';end if;
 select *into c from public.fundraising_campaigns where id=x.campaign_id;
 if coalesce((i->>'anonymous')::boolean,false)and not c.allow_anonymous or coalesce((i->>'fee_cover')::boolean,false)and not c.allow_fee_cover then raise exception'Campaign preference unavailable'using errcode='PT422';end if;
 perform 1 from public.money_board_tiles t join public.money_board_group_items l on l.tile_id=t.id where l.group_id=g.id order by t.id for update of t;
 if exists(select 1 from public.money_board_group_items l join public.money_board_reservations r on r.id=l.reservation_id where l.group_id=g.id and(r.released_at is not null or r.expires_at<=clock_timestamp()))then raise exception'Group reservation ended'using errcode='PT409';end if;
 attribution:=case when x.context->>'share_id' is not null then case when i->>'source'='qr'then'qr'else'participant_share'end when x.context->>'team_id' is not null then'team_campaign'else'organization_campaign'end;
 insert into public.fundraising_donors(display_name,email,mobile)values(btrim(i->>'display_name'),nullif(btrim(i->>'email'),''),nullif(btrim(i->>'mobile'),''))returning id into donor;
 subcap:=encode(sha256(convert_to(session_capability||':'||g.id,'UTF8')),'hex');
 insert into public.fundraising_intents(campaign_id,fundraiser_id,donor_id,share_id,amount_minor,currency,anonymous,fee_cover,source_kind,provenance,reward_policy,capability_digest,expires_at,request_id)
 values(x.campaign_id,x.fundraiser_id,donor,(x.context->>'share_id')::uuid,g.amount_minor,g.currency,coalesce((i->>'anonymous')::boolean,false),coalesce((i->>'fee_cover')::boolean,false),attribution,
 boss_private.money_board_provenance(x.id)||jsonb_build_object('organization_id',x.organization_id,'restricted_use_organization_id',x.organization_id,'household_id',(select household_id from public.fundraising_fundraisers where id=x.fundraiser_id),
 'channel','money_board_group','board_id',x.board_id,'generation_id',x.generation_id,'group_id',g.id,'currency',x.currency,'amount_minor',g.amount_minor,'policy_revision',p.revision,'source_kind',attribution),c.reward_policy,
 encode(sha256(convert_to(subcap,'UTF8')),'hex'),g.expires_at,request)returning id into intent;
 insert into public.money_board_checkout_preparations(group_id,intent_id,request_id)values(g.id,intent,request);
 insert into public.fundraising_intent_events(intent_id,state)values(intent,'awaiting_payment');
 end if;
 result:=boss_private.money_board_cart_projection(x.id)||jsonb_build_object('action',a,'replayed',false);
 if a not in('read','recover','revalidate')then
 insert into boss_private.money_board_cart_receipts(request_id,cart_id,input_hash,result)values(request,x.id,h,result);
 insert into public.money_board_cart_history(cart_id,action,request_id)values(x.id,a,request);end if;
 return result;
 exception when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation then raise exception'Invalid cart input'using errcode='PT422';when unique_violation then raise exception'Cart request conflict'using errcode='PT409';
end$$;
create function boss_fundraising_public.cart(command jsonb,session_capability text)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.money_board_cart_command(command,session_capability)$$;
create function public.boss_money_board_cart(command jsonb,session_capability text)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_fundraising_public.cart(command,session_capability)$$;
revoke all on function boss_fundraising_public.cart(jsonb,text),public.boss_money_board_cart(jsonb,text)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_fundraising_public.cart(jsonb,text),public.boss_money_board_cart(jsonb,text)to anon,authenticated;
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='boss_private'::regnamespace and proname like'money_board_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.sig);end loop;end$$;
