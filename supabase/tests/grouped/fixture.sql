\ir ../phase7d/fixture.sql
create function pg_temp.cart(a text,cap text,extra jsonb default '{}'::jsonb,req uuid default gen_random_uuid())returns jsonb language sql as $$
 select public.boss_money_board_cart(jsonb_build_object('action',a,'request_id',req,'input',jsonb_build_object('path',pg_temp.fpath('share'))||extra),cap)$$;
grant execute on function pg_temp.cart(text,text,jsonb,uuid)to anon,authenticated;
create function pg_temp.tile(n int)returns uuid language sql security definer set search_path='' as $$select id from public.money_board_tiles where board_id=pg_temp.fid('board')and generation_id=(select id from public.money_board_generations where board_id=pg_temp.fid('board')order by generation desc limit 1)and ordinal=n$$;
grant execute on function pg_temp.tile(int)to anon,authenticated;
create temp table group_results(label text primary key,data jsonb);grant all on group_results to anon,authenticated;
update public.organization_modules set configuration=configuration||'{"refunds":true,"reconciliation":true}'::jsonb where module_id=(select id from public.modules where key='payments');
create function pg_temp.group_checkout(label text,method text default 'card',ordinals int[]default array[5,10,15],short boolean default false)returns uuid language plpgsql as $$
 declare n int;rid uuid;x public.money_board_carts;at_time timestamptz;cap text:=md5(label)||md5('group'||label);g public.money_board_groups;i public.fundraising_intents;begin
 perform pg_temp.cart('open',cap);for n in select unnest(ordinals)loop perform pg_temp.cart('add',cap,jsonb_build_object('tile_id',pg_temp.tile(n)));end loop;
 if not short then perform pg_temp.cart('reserve',cap);else
 -- Construct a consistent already-running synthetic 600s window with 1s remaining.
 -- Immutable histories are inserted once, never rewritten or disabled.
 select *into x from public.money_board_carts where capability_digest=encode(sha256(convert_to(cap,'UTF8')),'hex');at_time:=clock_timestamp()-interval'599 seconds';
 insert into public.money_board_groups(cart_id,request_id,amount_minor,currency,policy_revision,starts_at,expires_at)values(x.id,gen_random_uuid(),(select sum(amount_minor)from public.money_board_cart_items where cart_id=x.id),x.currency,x.policy_revision,at_time,at_time+interval'600 seconds')returning *into g;
 for n in select unnest(ordinals)loop
 insert into public.money_board_reservations(tile_id,capability_digest,starts_at,expires_at,request_id)values(pg_temp.tile(n),md5(label||n)||md5('hold'||label||n),g.starts_at,g.expires_at,gen_random_uuid())returning id into rid;
 insert into public.money_board_group_items(group_id,tile_id,reservation_id,amount_minor,provenance)select g.id,tile_id,rid,amount_minor,provenance from public.money_board_cart_items where cart_id=x.id and tile_id=pg_temp.tile(n);
 end loop;end if;
 perform pg_temp.cart('prepare',cap,'{"display_name":"Synthetic grouped supporter","anonymous":true}');
 select *into g from public.money_board_groups where cart_id=(select id from public.money_board_carts where capability_digest=encode(sha256(convert_to(cap,'UTF8')),'hex'))order by starts_at desc limit 1;
 select fi.*into i from public.money_board_checkout_preparations p join public.fundraising_intents fi on fi.id=p.intent_id where p.group_id=g.id;
 insert into public.payment_checkouts(id,organization_id,intent_id,purpose,currency,account_id,routing_id,policy_id,method,principal_minor,external_minor,request_id,command_hash,capability_digest,expires_at)
 values(pg_temp.f('checkout-'||label),pg_temp.f('org'),i.id,'fundraising',i.currency,pg_temp.f('rails-account'),pg_temp.f('fundraising-route'),pg_temp.f('settlement-policy'),method,i.amount_minor,i.amount_minor,pg_temp.f('checkout-request-'||label),repeat('c',64),i.capability_digest,i.expires_at);
 return pg_temp.f('checkout-'||label);end$$;
create function pg_temp.group_id(label text)returns uuid language sql as $$select group_id from public.money_board_checkout_preparations where intent_id=(select intent_id from public.payment_checkouts where id=pg_temp.f('checkout-'||label))$$;
create function pg_temp.group_evidence(label text)returns uuid language sql as $$select id from public.fundraising_success_evidence where intent_id=(select intent_id from public.payment_checkouts where id=pg_temp.f('checkout-'||label))$$;
create function pg_temp.refund_group(label text,amount bigint,exact jsonb default null)returns uuid language plpgsql as $$
 declare r jsonb;payment uuid;event uuid;begin
 select payment_id into payment from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-'||label)and original_payment_id is null;
 r:=boss_private.rails_refund_prepare(pg_temp.f('admin'),jsonb_build_object('action','refund.prepare','request_id',gen_random_uuid(),'input',jsonb_build_object('payment_id',payment,'amount_minor',amount,'principal_minor',amount,'allocations','[]'::jsonb,'reason','Disposable original-source correction')));
 perform boss_private.rails_refund_dispatch((r->>'refund_id')::uuid);
 if exact is not null then
 insert into public.provider_event_evidence(account_id,operation_id,event_reference,kind,transaction_reference,amount_minor,currency,occurred_at,body_digest)
 select account_id,id,label||'-refund-'||amount,'refunded','LOCAL-GROUP-REFUND-'||label||amount,amount,'USD',clock_timestamp(),repeat('d',64)from public.provider_operations where id=(select operation_id from public.payment_refund_requests where id=(r->>'refund_id')::uuid)returning id into event;
 insert into public.money_board_correction_plans(event_id,allocations)values(event,exact);
 perform boss_private.rails_external_correct(payment,event,'refund',amount,'[]',(r->>'refund_id')::uuid);
 else perform boss_private.rails_refund_receive((r->>'refund_id')::uuid,label||'-refund-'||amount,'refunded','LOCAL-GROUP-REFUND-'||label||amount,amount,'USD',clock_timestamp(),repeat('d',64));end if;
 select id into event from public.provider_event_evidence where event_reference=label||'-refund-'||amount;
 return event;end$$;
