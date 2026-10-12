create function boss_private.money_board_progress_v2(board uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
 declare b public.money_boards;g uuid;gross bigint;corrected bigint;claimed bigint;reserved bigint;pending bigint;begin
 select *into b from public.money_boards where id=board;select id into g from public.money_board_generations where board_id=b.id order by generation desc limit 1;
 select coalesce(sum(c.amount_minor),0),count(*)into gross,claimed from public.money_board_tile_claims c join public.money_board_tiles t on t.id=c.tile_id where t.board_id=b.id;
 select coalesce(sum(r.amount_minor),0)into corrected from public.money_board_tile_corrections r join public.money_board_tiles t on t.id=r.tile_id where t.board_id=b.id;
 select count(*)into reserved from(
 select r.tile_id from public.money_board_reservations r join public.money_board_tiles t on t.id=r.tile_id where t.board_id=b.id and t.generation_id=g and r.released_at is null and r.expires_at>clock_timestamp()
 union
 select l.tile_id from public.money_board_group_items l join public.money_board_groups gg on gg.id=l.group_id join public.money_board_carts x on x.id=gg.cart_id join public.money_board_checkout_preparations p on p.group_id=gg.id join public.payment_checkouts pc on pc.intent_id=p.intent_id where x.board_id=b.id and x.generation_id=g and pc.state<>'ready'and boss_private.rails_hold(pc.id)
 union
 select i.tile_id from public.fundraising_intents i join public.payment_checkouts pc on pc.intent_id=i.id join public.money_board_tiles t on t.id=i.tile_id where i.board_id=b.id and t.generation_id=g and pc.state<>'ready'and boss_private.rails_hold(pc.id)
 )held where not exists(select 1 from public.money_board_tile_claims where tile_id=held.tile_id);
 select coalesce(sum(gg.amount_minor),0)into pending from public.money_board_groups gg join public.money_board_carts x on x.id=gg.cart_id where x.board_id=b.id and boss_private.money_board_group_state(gg.id)in('awaiting_payment','payment_pending');
 pending:=pending+coalesce((select sum(i.amount_minor)from public.fundraising_intents i where i.board_id=b.id and i.tile_id is not null and not exists(select 1 from public.fundraising_success_evidence where intent_id=i.id)and exists(select 1 from public.money_board_reservations r where r.id=i.reservation_id and r.released_at is null and(r.expires_at>clock_timestamp()or boss_private.rails_tile_pending(i.tile_id)))),0);
 return jsonb_build_object('scope','money_board','verified_gross_minor',gross,'confirmed_corrections_minor',corrected,'net_raised_minor',gross-corrected,'claimed_count',claimed,'reserved_count',reserved,'available_count',b.tile_count-claimed-reserved,'pending_checkout_minor',pending);end$$;
-- Version 2 is additive: historical gross projections and RPCs stay unchanged.
create function boss_private.money_board_public_v2(path text,after_ordinal integer default 0)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare ctx jsonb;b public.money_boards;g uuid;tiles jsonb;begin
 ctx:=boss_private.fundraising_public_context(path);select *into b from public.money_boards where id=(ctx->>'board_id')::uuid;
 if b.id is null then raise exception'Board unavailable'using errcode='PT404';end if;
 if after_ordinal<0 then raise exception'Invalid ordinal'using errcode='PT422';end if;
 select id into g from public.money_board_generations where board_id=b.id order by generation desc limit 1;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'ordinal',t.ordinal,'amount_minor',t.amount_minor,'state',case when c.tile_id is not null then'claimed'when boss_private.rails_tile_pending(t.id)then'payment_pending'when not boss_private.money_board_tile_available(t.id)then'reserved'else'available'end,
 'display_name',case when c.tile_id is null then null when i.anonymous then'Anonymous'else d.display_name end)order by t.ordinal),'[]')into tiles
 from(select *from public.money_board_tiles where board_id=b.id and generation_id=g and ordinal>after_ordinal order by ordinal limit 50)t
 left join public.money_board_tile_claims c on c.tile_id=t.id left join public.fundraising_success_evidence e on e.id=c.evidence_id left join public.fundraising_intents i on i.id=e.intent_id left join public.fundraising_donors d on d.id=i.donor_id;
 return jsonb_build_object('version',2,'board_id',b.id,'generation_id',g,'title',b.title,'goal_minor',b.goal_minor,'start_minor',b.start_minor,'increment_minor',b.increment_minor,'tile_count',b.tile_count,'currency',(select currency from public.fundraising_campaigns where id=b.campaign_id),
 'reservation_seconds',b.reservation_seconds,'max_tiles',(select max_tiles from public.money_board_cart_policies order by revision desc limit 1),'tiles',tiles,'progress',boss_private.money_board_progress_v2(b.id),'payment_available',false);
end$$;
create function boss_fundraising_public.board_v2(path text,after_ordinal integer default 0)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.money_board_public_v2(path,after_ordinal)$$;
create function public.boss_money_board_public(path text,after_ordinal integer default 0)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_fundraising_public.board_v2(path,after_ordinal)$$;
-- Spin is a finite suggestion, never a hold or a payment. A randomized starting
-- ordinal plus indexed wrap search avoids a global random sort/download.
create function boss_fundraising_public.board_candidate(path text,excluded uuid[]default array[]::uuid[])returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare ctx jsonb;b public.money_boards;g uuid;t public.money_board_tiles;first_ordinal integer;begin
 if excluded is null or array_position(excluded,null)is not null or cardinality(excluded)>1000 then raise exception'Invalid finite exclusions'using errcode='PT422';end if;
 ctx:=boss_private.fundraising_public_context(path);select *into b from public.money_boards where id=(ctx->>'board_id')::uuid;
 if b.id is null then raise exception'Board unavailable'using errcode='PT404';end if;
 select id into g from public.money_board_generations where board_id=b.id order by generation desc limit 1;first_ordinal:=1+floor(random()*b.tile_count)::integer;
 select *into t from public.money_board_tiles where board_id=b.id and generation_id=g and ordinal>=first_ordinal and not(id=any(excluded))and boss_private.money_board_tile_available(id)order by ordinal limit 1;
 if t.id is null then select *into t from public.money_board_tiles where board_id=b.id and generation_id=g and ordinal<first_ordinal and not(id=any(excluded))and boss_private.money_board_tile_available(id)order by ordinal limit 1;end if;
 return case when t.id is null then jsonb_build_object('candidate',null)else jsonb_build_object('candidate',jsonb_build_object('id',t.id,'ordinal',t.ordinal,'amount_minor',t.amount_minor))end;
end$$;
create function public.boss_money_board_candidate(path text,excluded uuid[]default array[]::uuid[])returns jsonb language sql volatile security invoker set search_path=''as $$select boss_fundraising_public.board_candidate(path,excluded)$$;
revoke all on function boss_private.money_board_public_v2(text,integer),boss_fundraising_public.board_v2(text,integer),public.boss_money_board_public(text,integer),boss_fundraising_public.board_candidate(text,uuid[]),public.boss_money_board_candidate(text,uuid[])from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_fundraising_public.board_v2(text,integer),public.boss_money_board_public(text,integer),boss_fundraising_public.board_candidate(text,uuid[]),public.boss_money_board_candidate(text,uuid[])to anon,authenticated;
-- Keep historical raised_minor unchanged. All tile states/counts share the
-- permanent claim registry; additive progress_v2 names gross/corrections/net.
alter function boss_private.fundraising_board_projection(uuid,integer)rename to fundraising_board_projection_before_grouped;
create function boss_private.fundraising_board_projection(board uuid,offset_ordinal integer default 0)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
 declare result jsonb;metrics jsonb;tiles jsonb;begin
 result:=boss_private.fundraising_board_projection_before_grouped(board,offset_ordinal);if result is null then return null;end if;
 metrics:=boss_private.money_board_progress_v2(board);
 select coalesce(jsonb_agg(case when exists(select 1 from public.money_board_tile_claims c join public.money_board_tiles t on t.id=c.tile_id where t.board_id=board and t.ordinal=(v.value->>'ordinal')::int)then v.value||jsonb_build_object('state','claimed')else v.value end order by v.ord),'[]')into tiles from jsonb_array_elements(result->'tiles')with ordinality v(value,ord);
 return result||jsonb_build_object('projection_version',2,'claimed_count',metrics->'claimed_count','progress_v2',metrics,'tiles',tiles);end$$;
revoke all on function boss_private.money_board_progress_v2(uuid),boss_private.fundraising_board_projection(uuid,integer),boss_private.fundraising_board_projection_before_grouped(uuid,integer)from public,anon,authenticated,service_role,boss_payment_worker;
