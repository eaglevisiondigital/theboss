create function boss_private.discount_member_identity()returns trigger language plpgsql set search_path=''as $$begin
 if old.subject_id is not null and new.subject_id is distinct from old.subject_id then raise exception'Claimed membership cannot transfer'using errcode='23514';end if;return new;
end$$;
create trigger discount_member_subject before update on public.discount_memberships for each row execute function boss_private.discount_member_identity();
create trigger discount_product_identity before update on public.discount_products for each row execute function boss_private.preserve_row_identity('id','code','kind','created_by','created_at');
create trigger discount_member_identity before update on public.discount_memberships for each row execute function boss_private.preserve_row_identity('id','product_id','subject_type','country','region','market','display_id','created_at');
create trigger discount_card_identity before update on public.discount_physical_cards for each row execute function boss_private.preserve_row_identity('id','batch_id','ordinal','serial','created_at');
create trigger discount_batch_identity before update on public.discount_card_batches for each row execute function boss_private.preserve_row_identity('id','revision_id','organization_id','campaign_id','owner_type','quantity','controlled','created_by','created_at');
create trigger discount_order_identity before update on public.discount_orders for each row execute function boss_private.preserve_row_identity('id','organization_id','buyer_person_id','subject_type','subject_id','campaign_id','fundraiser_id','share_id','channel','revision_id','quantity','currency','total_minor','base_source_id','request_id','command_digest','guest_digest','created_at');
create trigger discount_order_item_identity before update on public.discount_order_items for each row execute function boss_private.preserve_row_identity('id','order_id','ordinal','product_id','revision_id','kind','price_minor','organization_credit_minor','platform_retained_minor','product_cost_minor','tier','fulfillment_type','snapshot','created_at');
create trigger discount_campaign_product_identity before update on public.discount_campaign_products for each row execute function boss_private.preserve_row_identity('id','organization_id','campaign_id','revision_id','trial_enabled','gift_enabled','sale_enabled','starts_at','created_by','created_at');
create trigger discount_source_identity before update on public.discount_member_sources for each row execute function boss_private.preserve_row_identity('id','revision_id','kind','source_key','organization_id','campaign_id','fundraiser_id','donor_id','qualification_id','intent_id','tier','starts_at','ends_at','base_source_id','provenance','created_at');
create function boss_private.discount_source_member_move()returns trigger language plpgsql set search_path=''as $$begin
 if new.membership_id is distinct from old.membership_id and exists(select 1 from public.discount_memberships where id=old.membership_id and subject_id is not null)then raise exception'Claimed source cannot transfer'using errcode='23514';end if;return new;
end$$;
create trigger discount_source_member_move before update on public.discount_member_sources for each row execute function boss_private.discount_source_member_move();
create function boss_private.discount_source_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare s public.discount_member_sources;r public.discount_product_revisions;m public.discount_memberships;begin
 select *into s from public.discount_member_sources where id=new.id;select *into r from public.discount_product_revisions where id=s.revision_id;select *into m from public.discount_memberships where id=s.membership_id;
 if r.membership_product_id is distinct from m.product_id or r.subject_type is distinct from m.subject_type or r.country is distinct from m.country
 or r.region is distinct from m.region or r.market is distinct from m.market or s.tier<>r.tier or r.organization_id is not null and r.organization_id is distinct from s.organization_id then raise exception'Membership source product/subject/coverage mismatch'using errcode='23514';end if;
 if s.kind in('direct_purchase','fundraising_product_sale','renewal','tier_upgrade')and not exists(
 select 1 from public.discount_order_items i join public.discount_orders o on o.id=i.order_id join public.external_payment_tenders t on t.payment_id=o.payment_id
 where i.source_id=s.id and i.revision_id=r.id and t.purpose='products'and t.original_payment_id is null and o.checkout_id=t.checkout_id and o.organization_id=s.organization_id)
 then raise exception'Membership purchase requires canonical product payment lineage'using errcode='23514';end if;
 if s.kind='supporter_gift'and not exists(select 1 from public.fundraising_reward_qualifications q join public.fundraising_success_evidence e on e.id=q.evidence_id
 join public.discount_intent_product_snapshots ds on ds.intent_id=e.intent_id and ds.revision_id=r.id where q.id=s.qualification_id and q.qualified and q.status='gift_pending'and e.intent_id=s.intent_id)
 then raise exception'Gift requires trusted qualification and snapshotted product'using errcode='23514';end if;
 if s.kind='physical_card_digital_trial'and not exists(select 1 from public.discount_physical_cards c join public.discount_card_batches b on b.id=c.batch_id
 where s.source_key='card-trial:'||c.id and b.revision_id=r.id and c.membership_id=m.id and c.claimed_at=s.starts_at and s.ends_at=s.starts_at+make_interval(days=>r.trial_days))
 then raise exception'Physical digital trial requires canonical activation'using errcode='23514';end if;
 return null;
end$$;
create constraint trigger discount_source_proof after insert or update on public.discount_member_sources deferrable initially deferred for each row execute function boss_private.discount_source_proof();
-- Canonical dated entitlements are a projection, never the source of truth.
do $$declare d text;needle text;begin
 d:=pg_get_functiondef('boss_private.has_active_entitlement(text,uuid,text,text)'::regprocedure);
 needle:='and e.entitlement_key = p_entitlement_key and e.status = ''active''';
 if position(needle in d)=0 then raise exception'Canonical entitlement checkpoint mismatch';end if;
 d:=replace(d,needle,needle||' and (e.source_type is distinct from ''discount_member_source'' or boss_private.discount_source_valid(e.source_id))');
 d:=replace(d,'LANGUAGE sql STABLE','LANGUAGE sql VOLATILE');execute d;
end$$;
do $$declare t text;p record;begin
foreach t in array array['discount_product_revisions','discount_revision_events','discount_source_revocations','discount_membership_history','discount_entitlement_links','discount_intent_product_snapshots','discount_card_history','discount_order_history','discount_fulfillment_history','discount_product_credits','discount_refund_items']loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'discount_%'and proname not in('discount_read','discount_mutate')loop execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;

-- Commercial identity survives cancellation and cleanup.
do $$declare t text;begin foreach t in array array['discount_products','discount_campaign_products','discount_memberships','discount_member_sources','discount_card_batches','discount_physical_cards','discount_orders','discount_order_items','discount_fulfillments']loop
 execute format('create trigger %I before delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_no_delete',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;end$$;
create function boss_private.discount_entitlement_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$begin
 if new.source_type='discount_member_source'and not exists(select 1 from public.discount_entitlement_links l join public.discount_member_sources s on s.id=l.source_id
 join public.discount_memberships m on m.id=s.membership_id where l.entitlement_id=new.id and s.id=new.source_id and new.subject_type=m.subject_type and new.subject_id=m.subject_id
 and new.entitlement_type='product'and new.entitlement_key='boss_bucks.discounts:'||s.id and new.starts_at=s.starts_at and new.ends_at=s.ends_at
 and new.configuration=jsonb_build_object('membership_id',m.id,'tier',s.tier,'country',m.country,'region',m.region,'market',m.market))then raise exception'Exact discount entitlement projection required'using errcode='23514';end if;return null;
end$$;
create constraint trigger discount_entitlement_proof after insert or update on public.entitlements deferrable initially deferred for each row execute function boss_private.discount_entitlement_proof();
create function boss_private.discount_card_order_review(card uuid)returns boolean language sql volatile security definer set search_path=''as $$
 with recursive lineage as(select id,replaced_by,order_item_id from public.discount_physical_cards where id=card union all select p.id,p.replaced_by,p.order_item_id from public.discount_physical_cards p join lineage l on p.replaced_by=l.id)
 select exists(select 1 from lineage l join public.discount_order_items i on i.id=l.order_item_id join public.discount_orders o on o.id=i.order_id where o.state='review')
$$;
-- Hold only disputed order sources; original trials retain their own lifecycle.
do $$declare d text;needle text;begin
 d:=pg_get_functiondef('boss_private.discount_source_valid(uuid)'::regprocedure);
 needle:='and not exists(select 1 from public.discount_source_revocations v where v.source_id=s.id)';
 if position(needle in d)=0 then raise exception'Discount source lifecycle checkpoint mismatch';end if;
 d:=replace(d,needle,needle||' and not exists(select 1 from public.discount_order_items oi join public.discount_orders o on o.id=oi.order_id where oi.source_id=s.id and o.state=''review'')');execute d;
 d:=pg_get_functiondef('boss_private.discount_claim(uuid,text,uuid)'::regprocedure);
 if position(needle in d)=0 then raise exception'Discount claim lifecycle checkpoint mismatch';end if;
 d:=replace(d,needle,needle||' and not exists(select 1 from public.discount_order_items oi join public.discount_orders o on o.id=oi.order_id where oi.source_id=s.id and o.state=''review'')');execute d;
 d:=pg_get_functiondef('boss_private.discount_card_valid(uuid)'::regprocedure);
 needle:='and b.status<>''archived''';if position(needle in d)=0 then raise exception'Physical lifecycle checkpoint mismatch';end if;
 d:=replace(d,needle,needle||' and not boss_private.discount_card_order_review(c.id)');execute d;
end$$;
revoke all on function boss_private.discount_entitlement_proof()from public,anon,authenticated,service_role,boss_payment_worker;

create index discount_entitlement_expiry_idx on public.discount_member_sources(ends_at,membership_id);
create index discount_card_activation_expiry_idx on public.discount_physical_cards(claimed_at,id)where state in('claimed','active');
create function boss_private.discount_expire_batch(p_limit integer default 100)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare member uuid;card public.discount_physical_cards;n integer:=0;cards integer:=0;begin
 if p_limit not between 1 and 500 then raise exception'Bounded lifecycle batch required'using errcode='PT422';end if;
 for member in select distinct s.membership_id from public.discount_member_sources s join public.discount_entitlement_links l on l.source_id=s.id join public.entitlements e on e.id=l.entitlement_id
 where s.ends_at<=clock_timestamp()and e.status='active'order by s.membership_id limit p_limit loop perform boss_private.discount_rebuild(member);n:=n+1;end loop;
 for card in select c.*from public.discount_physical_cards c join public.discount_card_batches b on b.id=c.batch_id join public.discount_product_revisions r on r.id=b.revision_id
 where c.state not in('void','expired','replaced')and case r.validity_anchor when'activation'then c.claimed_at when'print'then c.printed_at when'sale'then c.sold_at end+make_interval(days=>r.card_validity_days)<=clock_timestamp()
 order by c.id limit p_limit for update of c skip locked loop
 update public.discount_physical_cards set state='expired',updated_at=clock_timestamp(),version=version+1 where id=card.id;
 update boss_private.discount_card_secrets set revoked_at=clock_timestamp()where card_id=card.id;
 insert into public.discount_card_history(card_id,action,organization_id,campaign_id,fundraiser_id)values(card.id,'expired',card.organization_id,card.campaign_id,card.fundraiser_id);cards:=cards+1;end loop;
 return jsonb_build_object('memberships_projected',n,'physical_credentials_expired',cards);
end$$;

-- Finite membership events reuse Phase 4A preferences, recipient deduplication,
-- unread state and delivery history. Payloads contain no activation/claim code.
alter table public.notification_events drop constraint notification_events_source_type_check;
alter table public.notification_events add constraint notification_events_source_type_check check(source_type in('event','registration','registration_document','charge','payment','message','attendance_request','volunteer_shift','volunteer_assignment','volunteer_event','game_operation','tournament_advancement','achievement_history','fundraising_history','boss_bucks_history','discount_membership_history'));
insert into boss_private.notification_types(key,category,source_module,title,body)values
 ('discounts.trial','fees','boss_bucks','Discounts trial started','Your configured Boss Bucks Discounts trial is available.'),
 ('discounts.activated','fees','boss_bucks','Discounts membership updated','Your membership source and coverage are available in Boss Bucks Discounts.'),
 ('discounts.gift','fees','boss_bucks','Supporter gift ready','A verified supporter gift is ready for its private membership claim.'),
 ('discounts.fulfillment','fees','boss_bucks','Physical card delivery updated','Your configured physical card delivery state has changed.'),
 ('discounts.upgrade','fees','boss_bucks','Coverage upgrade active','Your approved coverage upgrade is available in Boss Bucks Discounts.');
create function boss_private.discount_notification_visible(e public.notification_events,actor uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select e.source_type='discount_membership_history'and e.source_module='boss_bucks'and boss_private.notification_person_active(actor)
 and boss_private.discount_feature(e.organization_id,'discount_membership')and exists(select 1 from public.discount_membership_history h where h.id=e.source_id and h.organization_id=e.organization_id and(
 exists(select 1 from public.discount_memberships m where m.id=h.membership_id and boss_private.discount_subject(actor,m.subject_type,m.subject_id))
 or exists(select 1 from public.discount_fulfillments f join public.discount_order_items i on i.id=f.item_id join public.discount_orders o on o.id=i.order_id
 where f.id=h.resource_id and o.organization_id=e.organization_id and o.buyer_person_id=actor and boss_private.discount_subject(actor,o.subject_type,o.subject_id))))
$$;
alter function boss_private.notification_source_visible(public.notification_events,uuid)rename to notification_source_visible_phase7d;
create function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid)returns boolean language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type='discount_membership_history'then return boss_private.discount_notification_visible(p_event,p_person);end if;return boss_private.notification_source_visible_phase7d(p_event,p_person);end$$;
alter function boss_private.notification_candidates(public.notification_events,uuid,integer)rename to notification_candidates_phase7d;
create function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer)returns table(person_id uuid)language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type<>'discount_membership_history'then return query select *from boss_private.notification_candidates_phase7d(p_event,p_after,p_limit);return;end if;
 return query select x.person_id from(
 select m.person_id from public.discount_membership_history h join public.discount_memberships m on m.id=h.membership_id where h.id=p_event.source_id and m.person_id is not null
 union select hm.person_id from public.discount_membership_history h join public.discount_memberships m on m.id=h.membership_id join public.household_memberships hm on hm.household_id=m.household_id
 where h.id=p_event.source_id and hm.status='active'and hm.starts_at<=clock_timestamp()and(hm.ends_at is null or hm.ends_at>clock_timestamp())
 union select o.buyer_person_id from public.discount_membership_history h join public.discount_fulfillments f on f.id=h.resource_id join public.discount_order_items i on i.id=f.item_id join public.discount_orders o on o.id=i.order_id where h.id=p_event.source_id and o.buyer_person_id is not null
 )x where(p_after is null or x.person_id>p_after)and boss_private.discount_notification_visible(p_event,x.person_id)order by x.person_id limit p_limit;
end$$;
alter function boss_private.notification_contexts(public.notification_events,uuid)rename to notification_contexts_phase7d;
create function boss_private.notification_contexts(p_event public.notification_events,p_person uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type='discount_membership_history'then return jsonb_build_array(jsonb_build_object('kind','boss_bucks','source_id',p_event.source_id));end if;return boss_private.notification_contexts_phase7d(p_event,p_person);end$$;
alter function boss_private.notification_destination(public.notification_events)rename to notification_destination_phase7d;
create function boss_private.notification_destination(p_event public.notification_events)returns text language plpgsql stable security definer set search_path=''as $$begin
 if p_event.source_type='discount_membership_history'then return'/app/boss-bucks/discounts';end if;return boss_private.notification_destination_phase7d(p_event);end$$;
create function boss_private.discount_notification_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$declare k text;org uuid;kind text;begin
 org:=new.organization_id;
 if org is null and new.membership_id is not null then select organization_id into org from public.discount_member_sources where membership_id=new.membership_id order by created_at,id limit 1;end if;
 if new.action='membership.source.issued'then kind:=new.details->>'kind';k:=case when kind in('fundraising_trial','physical_card_digital_trial')then'discounts.trial'when kind='supporter_gift'then'discounts.gift'when kind='tier_upgrade'then'discounts.upgrade'else'discounts.activated'end;
 elsif new.action in('membership.claimed','card.claimed')then k:='discounts.activated';
 elsif new.action in('product.fulfillment.ready_for_pickup','product.fulfillment.shipped','product.fulfillment.delivered')then k:='discounts.fulfillment';end if;
 if org is not null and k is not null then perform boss_private.notification_enqueue('boss_bucks','discount_membership_history',new.id,org,k,'1','{}');end if;return new;
end$$;
create trigger discount_notification_source after insert on public.discount_membership_history for each row execute function boss_private.discount_notification_ingest();
-- Store canonical organization context for claimed-member events before enqueue.
create function boss_private.discount_history_context()returns trigger language plpgsql set search_path=''as $$begin
 if new.organization_id is null and new.membership_id is not null then select organization_id into new.organization_id from public.discount_member_sources where membership_id=new.membership_id order by created_at,id limit 1;end if;return new;
end$$;
create trigger discount_history_context before insert on public.discount_membership_history for each row execute function boss_private.discount_history_context();
revoke all on function boss_private.notification_source_visible(public.notification_events,uuid),boss_private.notification_source_visible_phase7d(public.notification_events,uuid),boss_private.notification_candidates(public.notification_events,uuid,integer),boss_private.notification_candidates_phase7d(public.notification_events,uuid,integer),boss_private.notification_contexts(public.notification_events,uuid),boss_private.notification_contexts_phase7d(public.notification_events,uuid),boss_private.notification_destination(public.notification_events),boss_private.notification_destination_phase7d(public.notification_events)from public,anon,authenticated,service_role,boss_payment_worker;
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'discount_%'and proname not in('discount_read','discount_mutate')loop execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;

-- Coverage never outlives or survives a held/revoked underlying source.
-- Complete foreign-key support only for the new membership/product relations.
-- Full leading-column indexes preserve the historical FK audit; partial access
-- indexes do not substitute for parent-update/deletion support.
do $$declare c record;columns text;index_name text;begin
 for c in select con.* ,ns.nspname,rel.relname from pg_catalog.pg_constraint con
 join pg_catalog.pg_class rel on rel.oid=con.conrelid join pg_catalog.pg_namespace ns on ns.oid=rel.relnamespace
 where con.contype='f'and ns.nspname in('public','boss_private')and rel.relname like'discount\_%'escape'\'
 and not exists(select 1 from pg_catalog.pg_index idx where idx.indrelid=con.conrelid and idx.indisvalid and idx.indpred is null and idx.indexprs is null
 and idx.indnkeyatts>=cardinality(con.conkey)and(idx.indkey::smallint[])[0:cardinality(con.conkey)-1]@>con.conkey)order by ns.nspname,rel.relname,con.conname loop
 select string_agg(format('%I',att.attname),','order by key.ordinal)into columns from unnest(c.conkey)with ordinality key(number,ordinal)
 join pg_catalog.pg_attribute att on att.attrelid=c.conrelid and att.attnum=key.number;
 index_name:=left(c.relname,36)||'_fk_'||substr(md5(c.conname),1,10)||'_idx';
 execute format('create index %I on %I.%I(%s)',index_name,c.nspname,c.relname,columns);
 end loop;end$$;

do $$declare d text;needle text;begin
 d:=pg_get_functiondef('boss_private.discount_source_valid(uuid)'::regprocedure);needle:='and b.starts_at<=clock_timestamp()and b.ends_at>clock_timestamp()';
 if position(needle in d)=0 then raise exception'Upgrade base checkpoint mismatch';end if;
 d:=replace(d,needle,needle||' and b.kind<>''tier_upgrade'' and (b.organization_id is null or boss_private.discount_feature(b.organization_id,''discount_membership'')) and not exists(select 1 from public.discount_order_items oi join public.discount_orders o on o.id=oi.order_id where oi.source_id=b.id and o.state=''review'')');execute d;
end$$;
