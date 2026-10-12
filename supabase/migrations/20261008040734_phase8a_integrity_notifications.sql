-- Cache the installed PostgreSQL IANA zone names once. Per-row enumeration of
-- pg_timezone_names scans and computes every offset; indexed names preserve
-- the same authoritative validation without doing that work for every location.
create table boss_private.merchant_timezones(name text primary key);
insert into boss_private.merchant_timezones select name from pg_timezone_names;
alter table boss_private.merchant_timezones enable row level security;
revoke all on boss_private.merchant_timezones from public,anon,authenticated,service_role,boss_payment_worker;
create function boss_private.merchant_row_contract()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare role text;begin
 if tg_table_name='merchant_modules'then
 if not exists(select 1 from public.modules where id=new.module_id and key='commerce')or exists(select 1 from jsonb_each(new.configuration)where jsonb_typeof(value)<>'boolean')then raise exception'Commerce boolean configuration required'using errcode='23514';end if;
 elsif tg_table_name in('merchant_locations','merchant_offer_families')then
 if not exists(select 1 from boss_private.merchant_timezones where name=case when tg_table_name='merchant_locations'then to_jsonb(new)->>'timezone'else to_jsonb(new)->>'usage_timezone'end)then raise exception'Authoritative timezone required'using errcode='23514';end if;
 elsif tg_table_name='merchant_access_assignments'then
 select key into role from public.roles where id=new.role_id;
 if role not in('merchant_owner','merchant_admin','location_manager','offer_editor','redemption_clerk')or role in('merchant_owner','merchant_admin')and new.location_id is not null or role in('location_manager','redemption_clerk')and new.location_id is null then raise exception'Exact merchant role scope required'using errcode='23514';end if;
 elsif tg_table_name='merchant_staff_assignments'then
 if not exists(select 1 from public.roles where id=new.role_id and key in('support_reviewer','merchant_network_staff'))then raise exception'Merchant staff role required'using errcode='23514';end if;
 elsif tg_table_name='merchant_sales_assignments'then
 if not exists(select 1 from public.roles where id=new.role_id and key in('sales_rep','regional_manager'))then raise exception'Sales role required'using errcode='23514';end if;
 end if;return new;
end$$;
do $$declare t text;begin foreach t in array array['merchant_modules','merchant_locations','merchant_offer_families','merchant_access_assignments','merchant_staff_assignments','merchant_sales_assignments']loop
 execute format('create trigger %I before insert or update on public.%I for each row execute function boss_private.merchant_row_contract()',t||'_contract',t);end loop;
 foreach t in array array['merchant_offer_revisions','merchant_offer_locations','merchant_offer_events','merchant_redemptions','merchant_redemption_corrections','merchant_history','merchant_sales_activities','merchant_sales_history']loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
 foreach t in array array['merchants','merchant_locations','merchant_offer_families','merchant_access_assignments','merchant_staff_assignments','merchant_claims','merchant_sales_assignments','merchant_sales_leads']loop
 execute format('create trigger %I before delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_no_delete',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;
create trigger merchant_identity before update on public.merchants for each row execute function boss_private.preserve_row_identity('id','created_by','created_at','controlled');
create trigger merchant_location_identity before update on public.merchant_locations for each row execute function boss_private.preserve_row_identity('id','merchant_id','market_id','timezone','created_at');
create trigger merchant_family_identity before update on public.merchant_offer_families for each row execute function boss_private.preserve_row_identity('id','merchant_id','usage_limit','reset_period','usage_timezone','period_start','period_end','created_by','created_at');
create trigger merchant_access_identity before update on public.merchant_access_assignments for each row execute function boss_private.preserve_row_identity('id','merchant_id','location_id','person_id','role_id','starts_at','granted_by','created_at');
create trigger merchant_staff_identity before update on public.merchant_staff_assignments for each row execute function boss_private.preserve_row_identity('id','merchant_id','person_id','role_id','starts_at','granted_by','created_at');
create trigger merchant_sales_identity before update on public.merchant_sales_assignments for each row execute function boss_private.preserve_row_identity('id','person_id','role_id','market_id','manager_id','starts_at','granted_by','created_at');
create trigger merchant_sales_lead_identity before update on public.merchant_sales_leads for each row execute function boss_private.preserve_row_identity('id','market_id','source','created_at');
create trigger merchant_claim_identity before update on public.merchant_claims for each row execute function boss_private.preserve_row_identity('id','merchant_id','person_id','statement','created_at');
create function boss_private.merchant_redemption_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare t boss_private.merchant_redemption_intents;f public.merchant_offer_families;begin
 select *into t from boss_private.merchant_redemption_intents where id=new.intent_id;
 select *into f from public.merchant_offer_families where id=new.family_id;
 if t.id is null or(new.person_id,new.membership_id,new.source_id,new.merchant_id,new.location_id,new.family_id,new.revision_id,new.window_key)is distinct from
 (t.person_id,t.membership_id,t.source_id,t.merchant_id,t.location_id,t.family_id,t.revision_id,t.window_key)
 or t.consumed_at is null or t.retired_at is not null or t.expires_at<=clock_timestamp()
 or not boss_private.merchant_available(new.revision_id,new.location_id)or not boss_private.merchant_feature(new.merchant_id,'redemption')
 or not boss_private.discount_source_valid(new.source_id)or not boss_private.rails_actor_current(new.person_id)
 or boss_private.merchant_membership_source(new.person_id,new.location_id)is null
 or not boss_private.merchant_can(new.clerk_id,'merchant_redemptions.manage',new.merchant_id,new.location_id)
 or boss_private.merchant_window(f)<>new.window_key
 or f.usage_limit is not null and boss_private.merchant_usage(new.person_id,new.family_id,new.window_key)>f.usage_limit then raise exception'Current exact redemption proof required'using errcode='23514';end if;
 return null;
end$$;
create constraint trigger merchant_redemption_proof after insert on public.merchant_redemptions deferrable initially deferred for each row execute function boss_private.merchant_redemption_proof();

-- Reuse canonical Phase 4A inbox/preferences/delivery state with an explicit
-- merchant source, preserving all existing organization-only source contracts.
alter table public.notification_events alter column organization_id drop not null;
alter table public.notification_events add column merchant_id uuid references public.merchants(id);
alter table public.notification_events add constraint notification_resource_boundary check(
 (source_type='merchant_history'and source_module='commerce'and organization_id is null)
 or(source_type<>'merchant_history'and organization_id is not null and merchant_id is null));
create index notification_events_merchant_idx on public.notification_events(merchant_id,scheduled_at,id);
alter table public.notification_events drop constraint notification_events_source_module_check;
alter table public.notification_events add constraint notification_events_source_module_check check(source_module in('calendar','registration','messaging','volunteers','sports','fundraising','boss_bucks','commerce'));
alter table public.notification_events drop constraint notification_events_source_type_check;
alter table public.notification_events add constraint notification_events_source_type_check check(source_type in('event','registration','registration_document','charge','payment','message','attendance_request','volunteer_shift','volunteer_assignment','volunteer_event','game_operation','tournament_advancement','achievement_history','fundraising_history','boss_bucks_history','discount_membership_history','merchant_history'));
create unique index notification_merchant_source_once_idx on public.notification_events(event_type,source_id,source_revision)where source_type='merchant_history';
alter table public.notifications alter column organization_id drop not null;
alter table public.notifications add constraint notifications_event_id_fk foreign key(notification_event_id)references public.notification_events(id);
alter table public.notification_deliveries alter column organization_id drop not null;
alter table public.notification_deliveries add constraint deliveries_notification_id_fk foreign key(notification_id)references public.notifications(id);
create function boss_private.merchant_notification_boundary()returns trigger language plpgsql volatile security definer set search_path=''as $$begin
 if tg_table_name='notification_events'then
 if new.source_type='merchant_history'and not exists(select 1 from public.merchant_history h where h.id=new.source_id and h.merchant_id is not distinct from new.merchant_id)then raise exception'Merchant notification lineage required'using errcode='23514';end if;
 elsif tg_table_name='notifications'then
 if not exists(select 1 from public.notification_events e where e.id=new.notification_event_id and e.organization_id is not distinct from new.organization_id)then raise exception'Notification context mismatch'using errcode='23514';end if;
 elsif not exists(select 1 from public.notifications n where n.id=new.notification_id and n.organization_id is not distinct from new.organization_id)then raise exception'Delivery context mismatch'using errcode='23514';end if;return new;
end$$;
create trigger merchant_notification_event_boundary before insert or update on public.notification_events for each row execute function boss_private.merchant_notification_boundary();
create trigger merchant_notification_boundary before insert or update on public.notifications for each row execute function boss_private.merchant_notification_boundary();
create trigger merchant_delivery_boundary before insert or update on public.notification_deliveries for each row execute function boss_private.merchant_notification_boundary();
insert into boss_private.notification_types(key,category,source_module,title,body)values
 ('merchant.approved','communications','commerce','Merchant review updated','A merchant listing decision is ready in your merchant workspace.'),
 ('merchant.offer_review','communications','commerce','Offer review updated','An offer review is ready in your merchant workspace.'),
 ('merchant.follow_up','communications','commerce','Merchant follow-up','A follow-up is ready in your assigned sales workspace.');
create function boss_private.merchant_notification_visible(e public.notification_events,actor uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select e.source_type='merchant_history'and e.source_module='commerce'and boss_private.notification_person_active(actor)and exists(
 select 1 from public.merchant_history h where h.id=e.source_id and h.merchant_id is not distinct from e.merchant_id and(
 h.action='merchant.lead.activity'and exists(select 1 from public.merchant_sales_activities a join public.merchant_sales_leads l on l.id=a.lead_id where a.id=h.resource_id and boss_private.merchant_sales_can(actor,l.market_id,l.rep_id))
 or h.action in('merchant.merchant.review','merchant.offer.status')and boss_private.merchant_feature(h.merchant_id,'portal')and exists(select 1 from public.merchant_access_assignments a where a.person_id=actor and a.merchant_id=h.merchant_id and a.location_id is null
 and a.created_at<=e.occurred_at and a.starts_at<=e.occurred_at and boss_private.merchant_can(actor,'merchants.view',h.merchant_id))))
$$;
alter function boss_private.notification_source_visible(public.notification_events,uuid)rename to notification_source_visible_phase7e;
create function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid)returns boolean language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type='merchant_history'then return boss_private.merchant_notification_visible(p_event,p_person);end if;return boss_private.notification_source_visible_phase7e(p_event,p_person);end$$;
alter function boss_private.notification_candidates(public.notification_events,uuid,integer)rename to notification_candidates_phase7e;
create function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer)returns table(person_id uuid)language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type<>'merchant_history'then return query select *from boss_private.notification_candidates_phase7e(p_event,p_after,p_limit);return;end if;
 return query select x.person_id from(
 select a.person_id from public.merchant_access_assignments a where a.merchant_id=p_event.merchant_id and a.location_id is null and a.status='active'
 union select l.rep_id from public.merchant_history h join public.merchant_sales_activities a on a.id=h.resource_id join public.merchant_sales_leads l on l.id=a.lead_id where h.id=p_event.source_id
 union select l.manager_id from public.merchant_history h join public.merchant_sales_activities a on a.id=h.resource_id join public.merchant_sales_leads l on l.id=a.lead_id where h.id=p_event.source_id and l.manager_id is not null
 )x where(p_after is null or x.person_id>p_after)and boss_private.merchant_notification_visible(p_event,x.person_id)order by x.person_id limit greatest(1,least(p_limit,100));
end$$;
alter function boss_private.notification_contexts(public.notification_events,uuid)rename to notification_contexts_phase7e;
create function boss_private.notification_contexts(p_event public.notification_events,p_person uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type='merchant_history'then return jsonb_build_array(jsonb_build_object('kind','merchant','merchant_id',p_event.merchant_id));end if;return boss_private.notification_contexts_phase7e(p_event,p_person);end$$;
alter function boss_private.notification_destination(public.notification_events)rename to notification_destination_phase7e;
create function boss_private.notification_destination(p_event public.notification_events)returns text language plpgsql stable security definer set search_path=''as $$begin
 if p_event.source_type='merchant_history'then return case when p_event.event_type='merchant.follow_up'then'/app/merchant-sales'else'/app/merchants?merchant_id='||p_event.merchant_id end;end if;return boss_private.notification_destination_phase7e(p_event);end$$;
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.notification_process(uuid,integer)'::regprocedure);
 if position('e.organization_id=p_org'in d)=0 then raise exception'Notification process checkpoint mismatch';end if;
 d:=replace(d,'e.organization_id=p_org','e.organization_id is not distinct from p_org');execute d;
end$$;
create function boss_private.merchant_notification_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$declare k text;e uuid;begin
 k:=case when new.action='merchant.merchant.review'then'merchant.approved'when new.action='merchant.offer.status'and new.details->>'state'in('published','scheduled','rejected','draft')then'merchant.offer_review'
 when new.action='merchant.lead.activity'then'merchant.follow_up'end;
 if k is not null then
 insert into public.notification_events(merchant_id,event_type,source_module,source_type,source_id,source_revision,safe_data,occurred_at,scheduled_at)
 values(new.merchant_id,k,'commerce','merchant_history',new.id,'1','{}',new.created_at,transaction_timestamp())returning id into e;
 insert into boss_private.notification_expansion_jobs(notification_event_id)values(e);
 perform boss_private.notification_process(null,50);
 end if;return new;
end$$;
create trigger merchant_notification_ingest after insert on public.merchant_history for each row execute function boss_private.merchant_notification_ingest();

-- Every FK receives a leading-column index when none already covers it.
do $$declare f record;n text;begin for f in select c.conrelid,c.conname,c.conkey,string_agg(quote_ident(a.attname),','order by x.ordinality)cols
 from pg_constraint c cross join lateral unnest(c.conkey)with ordinality x(attnum,ordinality)join pg_attribute a on a.attrelid=c.conrelid and a.attnum=x.attnum
 where c.contype='f'and(c.conrelid::regclass::text like'merchant_%'or c.conrelid::regclass::text='merchants'or c.conrelid::regclass::text like'boss_private.merchant_%')group by c.oid,c.conrelid,c.conname,c.conkey loop
 if not exists(select 1 from pg_index i where i.indrelid=f.conrelid and i.indisvalid and i.indpred is null and i.indkey::smallint[]@>f.conkey and i.indkey[0]=f.conkey[1])then
 n:=left(f.conname,51)||'_idx';execute format('create index %I on %s(%s)',n,f.conrelid::regclass,f.cols);end if;end loop;end$$;
do $$declare f record;begin
 for f in select oid::regprocedure name from pg_proc where pronamespace='boss_private'::regnamespace and proname like'merchant_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',f.name);end loop;
end$$;
revoke all on function public.boss_merchants_read(jsonb),public.boss_merchants_mutate(jsonb),public.boss_merchants_directory(jsonb),boss_merchants_public.directory(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_private.merchant_read(jsonb),boss_private.merchant_mutate(jsonb),public.boss_merchants_read(jsonb),public.boss_merchants_mutate(jsonb)to authenticated;
grant execute on function public.boss_merchants_directory(jsonb),boss_merchants_public.directory(jsonb)to anon,authenticated;
revoke all on function boss_private.notification_source_visible(public.notification_events,uuid),boss_private.notification_candidates(public.notification_events,uuid,integer),boss_private.notification_contexts(public.notification_events,uuid),boss_private.notification_destination(public.notification_events)from public,anon,authenticated,service_role,boss_payment_worker;

revoke all on function boss_merchants_public.options(jsonb)from public,anon,authenticated,service_role,boss_payment_worker;
