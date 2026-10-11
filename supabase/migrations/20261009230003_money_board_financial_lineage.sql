-- Reuse the Phase 7D/7E dispatch and fulfillment paths. No worker is enabled.
create or replace function boss_private.rails_tile_pending(tile uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.fundraising_intents i join public.payment_checkouts c on c.intent_id=i.id where c.state<>'ready'and boss_private.rails_hold(c.id)
 and(i.tile_id=tile or exists(select 1 from public.money_board_checkout_preparations p join public.money_board_group_items l on l.group_id=p.group_id where p.intent_id=i.id and l.tile_id=tile)))
$$;
create function boss_private.money_board_cart_path(cart uuid)returns text language sql volatile security definer set search_path=''as $$
 select v.path from public.money_board_carts x join public.money_boards b on b.id=x.board_id join public.fundraising_campaigns c on c.id=x.campaign_id left join public.fundraising_shares s on s.id=(x.context->>'share_id')::uuid
 cross join lateral(values(s.path),(b.public_path),(c.public_path))v(path)where x.id=cart and encode(sha256(convert_to(v.path,'UTF8')),'hex')=x.path_digest limit 1
$$;
alter function boss_private.rails_dispatch(uuid)rename to rails_dispatch_before_grouped;
create function boss_private.rails_dispatch(checkout uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare c public.payment_checkouts;p public.money_board_checkout_preparations;g public.money_board_groups;x public.money_board_carts;result jsonb;begin
 c:=boss_private.rails_checkout_fence(checkout);select *into p from public.money_board_checkout_preparations where intent_id=c.intent_id;
 if p.group_id is not null and not exists(select 1 from public.payment_eligibility_commits where checkout_id=c.id)then
 select *into g from public.money_board_groups where id=p.group_id;
 -- Private worker needs current canonical actor/resource eligibility, not a fabricated Auth session.
 select *into x from public.money_board_carts where id=g.cart_id;
 perform 1 from public.money_boards where id=x.board_id for update;
 perform 1 from public.money_board_tiles t join public.money_board_group_items l on l.tile_id=t.id where l.group_id=g.id order by t.id for update of t;
 if g.expires_at<=clock_timestamp()or g.amount_minor<>c.principal_minor or g.currency<>c.currency
 or not exists(select 1 from public.money_boards where id=x.board_id and status='published')
 or x.generation_id is distinct from(select id from public.money_board_generations where board_id=x.board_id order by generation desc limit 1)
 or boss_private.money_board_context(boss_private.money_board_cart_path(x.id))is distinct from x.context
 or x.actor_person_id is not null and not boss_private.rails_actor_current(x.actor_person_id)
 or exists(select 1 from public.money_board_group_items l join public.money_board_reservations r on r.id=l.reservation_id where l.group_id=g.id and(r.released_at is not null or r.expires_at<=clock_timestamp()or boss_private.rails_tile_pending(l.tile_id)or exists(select 1 from public.money_board_tile_claims where tile_id=l.tile_id)))then raise exception'Grouped checkout eligibility ended'using errcode='PT409';end if;
 end if;
 result:=boss_private.rails_dispatch_before_grouped(checkout);
 if p.group_id is not null and result->>'first_dispatch'='true'then
 insert into public.money_board_group_commits(checkout_id,group_id,snapshot)
 select c.id,p.group_id,jsonb_build_object('version',1,'group_id',p.group_id,'lines',jsonb_agg(jsonb_build_object('tile_id',l.tile_id,'reservation_id',l.reservation_id,'amount_minor',l.amount_minor)order by l.tile_id))from public.money_board_group_items l where l.group_id=p.group_id;
 end if;return result;
end$$;
create function boss_private.money_board_success_claims()returns trigger language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare g public.money_board_groups;x public.money_board_carts;committed uuid;line record;begin
 select gg.*into g from public.money_board_checkout_preparations p join public.money_board_groups gg on gg.id=p.group_id where p.intent_id=new.intent_id;
 if g.id is null then
 if new.tile_id is not null then insert into public.money_board_tile_claims(tile_id,evidence_id,amount_minor,provenance,claimed_at)values(new.tile_id,new.id,new.amount_minor,new.provenance,new.payment_success_at);end if;return new;end if;
 select *into x from public.money_board_carts where id=g.cart_id;
 perform 1 from public.money_boards where id=x.board_id for update;
 perform 1 from public.money_board_tiles t join public.money_board_group_items l on l.tile_id=t.id where l.group_id=g.id order by t.id for update of t;
 committed:=(new.provenance->>'committed_checkout_id')::uuid;
 if new.tile_id is not null or new.amount_minor<>g.amount_minor or new.currency<>g.currency
 or(select sum(amount_minor)from public.money_board_group_items where group_id=g.id)<>g.amount_minor
 or exists(select 1 from public.money_board_group_items l join public.money_board_tiles t on t.id=l.tile_id join public.money_board_reservations r on r.id=l.reservation_id where l.group_id=g.id and(t.board_id<>x.board_id or t.generation_id<>x.generation_id or t.amount_minor<>l.amount_minor or r.tile_id<>l.tile_id or r.released_at is not null))then raise exception'Grouped success lineage mismatch'using errcode='PT422';end if;
 if committed is null then
 if g.expires_at<=clock_timestamp()or boss_private.money_board_context(boss_private.money_board_cart_path(x.id))is distinct from x.context then raise exception'Group reservation context ended'using errcode='PT409';end if;
 elsif not exists(select 1 from public.money_board_group_commits gc join public.payment_eligibility_commits ec on ec.checkout_id=gc.checkout_id join public.payment_checkouts pc on pc.id=gc.checkout_id where gc.group_id=g.id and gc.checkout_id=committed and pc.intent_id=new.intent_id and gc.snapshot->'lines'=(select jsonb_agg(jsonb_build_object('tile_id',l.tile_id,'reservation_id',l.reservation_id,'amount_minor',l.amount_minor)order by l.tile_id)from public.money_board_group_items l where l.group_id=g.id))then raise exception'Frozen group success proof required'using errcode='PT422';end if;
 for line in select *from public.money_board_group_items where group_id=g.id order by tile_id loop
 insert into public.money_board_tile_claims(tile_id,evidence_id,group_id,amount_minor,provenance,claimed_at)values(line.tile_id,new.id,g.id,line.amount_minor,line.provenance||new.provenance||jsonb_build_object('tile_amount_minor',line.amount_minor,'checkout_principal_minor',new.amount_minor),new.payment_success_at);end loop;
 return new;
end$$;
create trigger money_board_success_lineage after insert on public.fundraising_success_evidence for each row execute function boss_private.money_board_success_claims();
-- Capped Hamilton allocation uses original weights and a stable ordinal/UUID tie.
-- Saturated lines are removed; every remaining cent is apportioned again. This
-- handles repeated corrections after exact prior allocations without negatives.
create function boss_private.money_board_allocate_correction(evidence uuid,amount bigint)returns table(tile_id uuid,amount_minor bigint,original_minor bigint,tie_order bigint)language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare ids uuid[];weights bigint[];caps bigint[];outcomes bigint[];ord bigint[];n int;j int;k bigint;step int;leftover bigint;weight_sum numeric;numerator numeric;part bigint;remainders numeric[];best int;begin
 select array_agg(c.tile_id order by t.ordinal,c.tile_id),array_agg(c.amount_minor order by t.ordinal,c.tile_id),array_agg(c.amount_minor-coalesce((select sum(r.amount_minor)from public.money_board_tile_corrections r where r.tile_id=c.tile_id),0)order by t.ordinal,c.tile_id),array_agg(t.ordinal::bigint order by t.ordinal,c.tile_id)
 into ids,weights,caps,ord from public.money_board_tile_claims c join public.money_board_tiles t on t.id=c.tile_id where c.evidence_id=evidence;
 n:=coalesce(array_length(ids,1),0);if n=0 or amount<0 or amount>(select coalesce(sum(v),0)from unnest(caps)v)then raise exception'Correction exceeds original remaining tile principal'using errcode='PT422';end if;
 outcomes:=array_fill(0::bigint,array[n]);leftover:=amount;
 while leftover>0 loop
 weight_sum:=0;for j in 1..n loop if caps[j]>outcomes[j]then weight_sum:=weight_sum+weights[j];end if;end loop;
 remainders:=array_fill(-1::numeric,array[n]);part:=leftover;
 for j in 1..n loop if caps[j]>outcomes[j]then
 numerator:=part::numeric*weights[j];k:=least(div(numerator,weight_sum)::bigint,caps[j]-outcomes[j]);outcomes[j]:=outcomes[j]+k;leftover:=leftover-k;
 if caps[j]>outcomes[j]then remainders[j]:=mod(numerator,weight_sum);end if;end if;end loop;
 -- Integer div/mod retain exact common-denominator remainder ordering. Numeric
 -- division could round near-equal fractions into a false tie at large principal.
 -- Original order provides an immutable tie-break, independent of input order.
 for step in 1..n loop exit when leftover=0;best:=0;
 for j in 1..n loop if remainders[j]>=0 and(best=0 or remainders[j]>remainders[best])then best:=j;end if;end loop;
 exit when best=0;outcomes[best]:=outcomes[best]+1;leftover:=leftover-1;remainders[best]:=-1;end loop;
 end loop;
 for j in 1..n loop if outcomes[j]>0 then tile_id:=ids[j];amount_minor:=outcomes[j];original_minor:=weights[j];tie_order:=ord[j];return next;end if;end loop;
end$$;
create function boss_private.money_board_attribute_correction(correction uuid)returns void language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare ec public.external_payment_corrections;evidence uuid;plan jsonb;leg jsonb;claim public.money_board_tile_claims;total bigint:=0;begin
 select *into ec from public.external_payment_corrections where reversal_payment_id=correction;
 select e.id into evidence from public.payments p join public.fundraising_success_evidence e on e.intent_id=p.fundraising_intent_id where p.id=ec.original_payment_id;
 if evidence is null or not exists(select 1 from public.money_board_tile_claims where evidence_id=evidence)then return;end if;
 perform 1 from public.money_board_tiles t join public.money_board_tile_claims c on c.tile_id=t.id where c.evidence_id=evidence order by t.id for update of t;
 if exists(select 1 from public.money_board_tile_corrections where correction_id=correction)then return;end if;
 select allocations into plan from public.money_board_correction_plans where event_id=ec.event_id;
 if plan is not null then
 if jsonb_typeof(plan)<>'array'or jsonb_array_length(plan)=0 or jsonb_array_length(plan)>1000 or(select count(distinct(value->>'tile_id')::uuid)from jsonb_array_elements(plan))<>jsonb_array_length(plan)then raise exception'Invalid exact tile correction'using errcode='PT422';end if;
 for leg in select value from jsonb_array_elements(plan)order by(value->>'tile_id')::uuid loop
 perform boss_private.athlete_input(leg,array['tile_id','amount_minor'],array['tile_id','amount_minor']);
 select *into claim from public.money_board_tile_claims where tile_id=(leg->>'tile_id')::uuid and evidence_id=evidence;
 if claim.tile_id is null or(leg->>'amount_minor')::bigint<1 or(leg->>'amount_minor')::bigint>claim.amount_minor-coalesce((select sum(amount_minor)from public.money_board_tile_corrections where tile_id=claim.tile_id),0)then raise exception'Exact correction outside remaining source'using errcode='PT422';end if;
 total:=total+(leg->>'amount_minor')::bigint;
 insert into public.money_board_tile_corrections(correction_id,tile_id,amount_minor,algorithm,original_minor,tie_order)values(correction,claim.tile_id,(leg->>'amount_minor')::bigint,'exact_v1',claim.amount_minor,(select ordinal from public.money_board_tiles where id=claim.tile_id));end loop;
 if total<>ec.principal_minor then raise exception'Exact correction principal mismatch'using errcode='PT422';end if;
 elsif ec.principal_minor>0 then
 insert into public.money_board_tile_corrections(correction_id,tile_id,amount_minor,algorithm,original_minor,tie_order)
 select correction,a.tile_id,a.amount_minor,'largest_remainder_original_capped_v1',a.original_minor,a.tie_order from boss_private.money_board_allocate_correction(evidence,ec.principal_minor)a;
 end if;
end$$;
create function boss_private.money_board_correction_trigger()returns trigger language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
begin perform boss_private.money_board_attribute_correction(new.reversal_payment_id);return new;end$$;
create trigger money_board_correction_lineage after insert on public.external_payment_corrections for each row execute function boss_private.money_board_correction_trigger();
-- Additive historical attribution only; no original payment/source is rewritten.
do $$declare c record;begin for c in select reversal_payment_id from public.external_payment_corrections order by created_at,reversal_payment_id loop perform boss_private.money_board_attribute_correction(c.reversal_payment_id);end loop;end$$;
create function boss_private.money_board_group_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column

declare g uuid;begin
 if tg_table_name='money_board_groups'then g:=new.id;else g:=new.group_id;end if;
 if g is not null and(select amount_minor from public.money_board_groups where id=g)is distinct from(select sum(amount_minor)from public.money_board_group_items where group_id=g)then raise exception'Group principal must equal immutable line sum'using errcode='PT422';end if;
 if exists(select 1 from public.money_board_groups gg join public.money_board_carts x on x.id=gg.cart_id join public.money_boards b on b.id=x.board_id join public.money_board_generations gen on gen.id=x.generation_id join public.fundraising_campaigns c on c.id=x.campaign_id join public.money_board_cart_policies p on p.revision=gg.policy_revision where gg.id=g and(b.campaign_id<>c.id or gen.board_id<>b.id or x.organization_id<>c.organization_id or gg.currency<>x.currency or x.currency<>c.currency or gg.policy_revision<>x.policy_revision or gg.amount_minor>p.max_total_minor or(select count(*)from public.money_board_group_items where group_id=g)not between 1 and p.max_tiles))
 or exists(select 1 from public.money_board_group_items l join public.money_board_groups gg on gg.id=l.group_id join public.money_board_carts x on x.id=gg.cart_id join public.money_board_tiles t on t.id=l.tile_id join public.money_board_reservations r on r.id=l.reservation_id left join public.money_board_cart_items ci on ci.cart_id=x.id and ci.tile_id=l.tile_id where gg.id=g and(ci.tile_id is null or t.board_id<>x.board_id or t.generation_id<>x.generation_id or t.amount_minor<>l.amount_minor or ci.amount_minor<>l.amount_minor or ci.provenance<>l.provenance or r.tile_id<>l.tile_id or r.starts_at<>gg.starts_at or r.expires_at<>gg.expires_at))then raise exception'Group immutable scope/amount/reservation proof mismatch'using errcode='PT422';end if;return null;end$$;
create constraint trigger money_board_group_sum after insert on public.money_board_groups deferrable initially deferred for each row execute function boss_private.money_board_group_proof();
create constraint trigger money_board_group_lines_sum after insert on public.money_board_group_items deferrable initially deferred for each row execute function boss_private.money_board_group_proof();
create function boss_private.money_board_preparation_proof()returns trigger language plpgsql security definer set search_path=''as $$
#variable_conflict use_column
 declare intent uuid;begin
 if tg_table_name='fundraising_intents'then intent:=new.id;else intent:=new.intent_id;end if;
 if exists(select 1 from public.fundraising_intents i where i.id=intent and i.provenance->>'channel'='money_board_group')and not exists(select 1 from public.money_board_checkout_preparations p join public.money_board_groups g on g.id=p.group_id join public.money_board_carts x on x.id=g.cart_id join public.fundraising_intents i on i.id=p.intent_id where i.id=intent and i.amount_minor=g.amount_minor and i.currency=g.currency and i.campaign_id=x.campaign_id and i.fundraiser_id is not distinct from x.fundraiser_id and i.board_id is null and i.tile_id is null and i.reservation_id is null and(i.provenance->>'group_id')::uuid=g.id and(i.provenance->>'board_id')::uuid=x.board_id and(i.provenance->>'generation_id')::uuid=x.generation_id and(i.provenance->>'organization_id')::uuid=x.organization_id and i.expires_at=g.expires_at)then raise exception'Group intent preparation proof mismatch'using errcode='PT422';end if;return null;end$$;
create constraint trigger money_board_intent_group_proof after insert on public.fundraising_intents deferrable initially deferred for each row execute function boss_private.money_board_preparation_proof();
create constraint trigger money_board_preparation_group_proof after insert on public.money_board_checkout_preparations deferrable initially deferred for each row execute function boss_private.money_board_preparation_proof();
-- Existing archive/regeneration code sees permanent groups through claims as
-- well as the original single-tile success rows; pending groups use rails guard.
create function boss_private.money_board_board_guard()returns trigger language plpgsql security definer set search_path=''as $$
#variable_conflict use_column
begin
 if (new.status='archived'and old.status<>'archived' or(new.start_minor,new.increment_minor,new.tile_count)is distinct from(old.start_minor,old.increment_minor,old.tile_count))and exists(select 1 from public.money_board_tiles t where t.board_id=old.id and boss_private.rails_tile_pending(t.id))then raise exception'Pending payment protects original board'using errcode='PT409';end if;
 if(new.start_minor,new.increment_minor,new.tile_count)is distinct from(old.start_minor,old.increment_minor,old.tile_count)and exists(select 1 from public.money_board_tile_claims c join public.money_board_tiles t on t.id=c.tile_id where t.board_id=old.id)then raise exception'Permanently claimed board cannot regenerate'using errcode='PT409';end if;return new;end$$;
create trigger money_board_group_board_guard before update on public.money_boards for each row execute function boss_private.money_board_board_guard();
create function boss_private.money_board_generation_guard()returns trigger language plpgsql security definer set search_path=''as $$
 begin
 perform 1 from public.money_boards where id=new.board_id for update;
 if exists(select 1 from public.money_board_tile_claims c join public.money_board_tiles t on t.id=c.tile_id where t.board_id=new.board_id)or exists(select 1 from public.money_board_tiles t where t.board_id=new.board_id and boss_private.rails_tile_pending(t.id))then raise exception'Claimed or pending board cannot regenerate'using errcode='PT409';end if;return new;
 end$$;
create trigger money_board_group_generation_guard before insert on public.money_board_generations for each row execute function boss_private.money_board_generation_guard();
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='boss_private'::regnamespace and(proname like'money_board_%'or proname='rails_dispatch_before_grouped')loop execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.sig);end loop;end$$;
revoke all on function boss_private.rails_dispatch(uuid)from public,anon,authenticated,service_role,boss_payment_worker;
