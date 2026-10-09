create function boss_private.partner_membership_source(actor uuid,p_product uuid,p_market uuid,minimum_tier text)returns uuid language sql volatile security definer set search_path=''as $$
 select ds.id from public.merchant_markets g join public.discount_memberships dm on dm.country=g.country and dm.product_id=p_product
 join public.discount_member_sources ds on ds.membership_id=dm.id
 where g.id=p_market and g.status='active'and boss_private.discount_subject(actor,dm.subject_type,dm.subject_id)and boss_private.discount_source_valid(ds.id)
 and boss_private.discount_tier_rank(ds.tier)>=boss_private.discount_tier_rank(minimum_tier)
 and(ds.tier='nationwide'or ds.tier='state'and dm.region=g.region or ds.tier='local'and dm.region=g.region and dm.market=g.market)
 order by boss_private.discount_tier_rank(ds.tier)desc,ds.ends_at desc,ds.id limit 1
$$;
create function boss_private.partner_decision(actor uuid,p_revision uuid,p_market uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare r public.partner_benefit_revisions;c public.partner_contract_revisions;p public.partner_providers;cfg public.partner_config_revisions;s public.partner_benefit_sources;g public.merchant_markets;src uuid;member_ok boolean:=false;territory_ok boolean:=false;catalog_ok boolean:=false;rights_ok boolean:=false;operational_ok boolean:=false;begin
 select *into r from public.partner_benefit_revisions where id=p_revision;
 perform pg_advisory_xact_lock_shared(hashtextextended('boss-partner:'||r.provider_id,0));
 if r.id is null then return jsonb_build_object('membership_eligible',false,'territory_eligible',false,'catalog_available',false,'provider_operational',false,'fulfillment_possible',false,'visible',false);end if;
 select *into c from public.partner_contract_revisions where id=r.contract_id;select *into p from public.partner_providers where id=r.provider_id;
 select *into cfg from public.partner_config_revisions where provider_id=p.id order by revision desc limit 1;
 select *into s from public.partner_benefit_sources where id=r.source_id;select *into g from public.merchant_markets where id=p_market and status='active';
 -- Existing source-validated membership engine, exact product and country/market.
 if actor is not null and boss_private.rails_actor_current(actor)then src:=boss_private.partner_membership_source(actor,r.product_id,p_market,case when boss_private.discount_tier_rank(r.minimum_tier)>=boss_private.discount_tier_rank(c.minimum_tier)then r.minimum_tier else c.minimum_tier end);end if;
 member_ok:=coalesce(exists(select 1 from public.discount_member_sources ds join public.discount_memberships dm on dm.id=ds.membership_id
 where ds.id=src and dm.product_id=r.product_id and dm.product_id=c.product_id and boss_private.discount_tier_rank(ds.tier)>=greatest(boss_private.discount_tier_rank(r.minimum_tier),boss_private.discount_tier_rank(c.minimum_tier))),false);
 territory_ok:=coalesce(g.id is not null and g.country=r.country and(r.region=''or r.region=g.region)and(r.market_id is null or r.market_id=g.id)
 and exists(select 1 from public.partner_territories t where t.contract_id=c.id and t.provider_id=p.id and t.country=g.country and(t.region=''or t.region=g.region)and(t.market_id is null or t.market_id=g.id)and t.status='active'and t.starts_at<=clock_timestamp()and t.ends_at>clock_timestamp()),false);
 rights_ok:=coalesce(boss_private.partner_contract_active(c.id)and c.display_rights and c.caching_rights and r.country=any(c.countries)and r.category=any(c.categories)and cfg.method=any(c.methods)
 and c.revision=(select max(x.revision)from public.partner_contract_revisions x where x.provider_id=p.id and boss_private.partner_contract_active(x.id)),false);
 catalog_ok:=coalesce(s.status='available'and s.current_revision=r.source_revision and s.last_verified_at>clock_timestamp()-make_interval(secs=>cfg.max_stale_seconds)
 and r.starts_at<=clock_timestamp()and r.ends_at>clock_timestamp()and(select state from public.partner_benefit_reviews where revision_id=r.id order by created_at desc,id desc limit 1)='reviewed',false);
 operational_ok:=coalesce(p.state='configured'and cfg.operational and cfg.credentials_ready and cfg.starts_at<=clock_timestamp()and(cfg.ends_at is null or cfg.ends_at>clock_timestamp())and'benefit_detail'=any(cfg.capabilities)and exists(select 1 from public.modules where id=cfg.module_id and key='commerce'and status='active'),false);
 return jsonb_build_object('membership_eligible',member_ok,'territory_eligible',territory_ok,'catalog_available',catalog_ok,'licensing_valid',rights_ok,
 'provider_operational',operational_ok,'fulfillment_possible',member_ok and territory_ok and rights_ok and catalog_ok and operational_ok,
 'visible',member_ok and territory_ok and rights_ok and catalog_ok and operational_ok);
end$$;
create function boss_private.partner_commission_evidence(transaction uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare t public.partner_transaction_sources;p public.partner_commission_policies;refund bigint;eligible bigint;amount bigint;ready boolean;canceled boolean;begin
 select *into t from public.partner_transaction_sources where id=transaction;
 if t.id is null then raise exception'Evidence unavailable'using errcode='PT404';end if;
 select *into p from public.partner_commission_policies where id=t.policy_id;
 select coalesce(sum(e.adjustment_minor),0)into refund from public.partner_transaction_events e where e.transaction_id=t.id and e.kind='refund'and not exists(select 1 from public.partner_transaction_events x where x.corrects_event_id=e.id);
 eligible:=greatest(0,t.eligible_minor-refund);
 ready:=exists(select 1 from public.partner_transaction_events where transaction_id=t.id and kind=p.recognition_condition);
 canceled:=exists(select 1 from public.partner_transaction_events where transaction_id=t.id and kind='canceled');
 amount:=case when canceled or eligible=0 then 0 when not ready then null when p.basis='zero'then 0 when p.basis='percentage'then floor(eligible::numeric*p.rate_ppm/1000000)::bigint when p.basis='fixed'and refund=0 then p.fixed_minor else null end;
 -- No guessed flat-fee refund allocation; unknown treatment stays unknown.
 return jsonb_build_object('transaction_id',t.id,'currency',t.currency,'eligible_minor',eligible,'contract_id',p.contract_id,'policy_id',p.id,'basis',p.basis,
 'condition_met',ready,'estimated_minor',amount,'synthetic',true,'earned_revenue',false,'settlement_executed',false);
end$$;
create function boss_private.partner_admin_detail(actor uuid,provider uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin
 if provider is null then return null;end if;
 return jsonb_build_object('contracts',coalesce((select jsonb_agg(v)from(select c.id,c.revision,c.document_reference,c.countries,c.categories,c.product_id,c.starts_at,c.ends_at,c.display_rights,c.caching_rights,
 coalesce((select state from public.partner_contract_events where contract_id=c.id order by created_at desc,id desc limit 1),'pending')state,c.created_by<>actor can_approve from public.partner_contract_revisions c where provider_id=provider order by revision desc limit 50)v),'[]'::jsonb),
 'territories',coalesce((select jsonb_agg(v)from(select id,country,region,market_id,status,ends_at from public.partner_territories where provider_id=provider order by id limit 50)v),'[]'::jsonb),
 'imports',coalesce((select jsonb_agg(v)from(select id,feed_sequence,kind,accepted,quarantined,withdrawn,created_at from public.partner_import_runs where provider_id=provider order by feed_sequence desc limit 50)v),'[]'::jsonb),
 'catalog',coalesce((select jsonb_agg(v)from(select r.id,r.title,r.source_revision,r.member_terms,r.exclusions,r.ends_at,coalesce((select state from public.partner_benefit_reviews where revision_id=r.id order by created_at desc,id desc limit 1),'pending')state from public.partner_benefit_revisions r where provider_id=provider order by id limit 50)v),'[]'::jsonb));
end$$;
create function boss_private.partner_read(query jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;mode text:=coalesce(query->>'mode','admin');provider uuid:=(query->>'provider_id')::uuid;lim integer:=least(50,greatest(1,coalesce((query->>'limit')::integer,20)));cursor uuid:=(query->>'after')::uuid;begin
 perform boss_private.require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.partner_keys(query,array['mode','provider_id','limit','after','market_id','category']);
 if actor is null or not boss_private.rails_actor_current(actor)then raise exception'Access denied'using errcode='PT403';end if;
 if mode='discovery'then
 -- All external adapters are locked OFF in 8B1. No mocks or private catalog escape.
 return jsonb_build_object('provenance','partner','benefits','[]'::jsonb,'operational',false,'reason','not_activated');
 end if;
 if mode not in('admin','catalog','revenue')then raise exception'Finite read mode required'using errcode='PT422';end if;
 perform boss_private.partner_require(actor,case when mode='revenue'then'partners.revenue_report'else'partners.view'end,provider);
 if mode='catalog'then
 if provider is null then raise exception'Exact provider required'using errcode='PT422';end if;
 return jsonb_build_object('operational',false,'catalog',coalesce((select jsonb_agg(v)from(select r.id,r.source_id,r.source_revision,r.title,r.category,r.country,r.minimum_tier,s.external_id,s.status,s.last_verified_at
 from public.partner_benefit_revisions r join public.partner_benefit_sources s on s.id=r.source_id where r.provider_id=provider and(cursor is null or r.id>cursor)order by r.id limit lim)v),'[]'::jsonb));
 elsif mode='revenue'then
 if provider is null then raise exception'Exact provider required'using errcode='PT422';end if;
 return jsonb_build_object('evidence_only',true,'transactions',coalesce((select jsonb_agg(boss_private.partner_commission_evidence(id))from(select id from public.partner_transaction_sources where provider_id=provider and(cursor is null or id>cursor)order by id limit lim)v),'[]'::jsonb));
 end if;
 return jsonb_build_object('operational',false,'details',boss_private.partner_admin_detail(actor,provider),'providers',coalesce((select jsonb_agg(v)from(select p.id,p.key,p.name,p.state,p.version,p.synthetic,
 coalesce((select jsonb_build_object('id',c.id,'revision',c.revision,'method',c.method,'capabilities',c.capabilities,'operational',c.operational,'credentials_ready',c.credentials_ready)from public.partner_config_revisions c where c.provider_id=p.id order by revision desc limit 1),'{}'::jsonb)configuration,
 (select count(*)from public.partner_benefit_sources s where s.provider_id=p.id)source_count
 from public.partner_providers p where(provider is null or p.id=provider)and(cursor is null or p.id>cursor)order by p.id limit lim)v),'[]'::jsonb));
end$$;
create function public.boss_partners_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.partner_mutate(command)$$;
create function public.boss_partners_read(query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.partner_read(query)$$;
create function public.boss_partners_directory()returns jsonb language sql stable security invoker set search_path=''as $$select jsonb_build_object('provenance','partner','benefits','[]'::jsonb,'operational',false,'reason','not_activated')$$;
create function boss_private.partner_immutable()returns trigger language plpgsql set search_path=''as $$begin raise exception'Immutable partner history'using errcode='23514';end$$;
create function boss_private.partner_anchor()returns trigger language plpgsql set search_path=''as $$begin
 if tg_op='DELETE'or tg_op='TRUNCATE'then raise exception'Partner history retained'using errcode='23514';end if;
 if tg_table_name='partner_catalog_snapshots'and(to_jsonb(new)-'status')is distinct from(to_jsonb(old)-'status')then raise exception'Immutable snapshot anchor'using errcode='23514';end if;
 if(to_jsonb(new)->'id')is distinct from(to_jsonb(old)->'id')or(to_jsonb(new)->'provider_id')is distinct from(to_jsonb(old)->'provider_id')or(to_jsonb(new)->'external_id')is distinct from(to_jsonb(old)->'external_id')or(to_jsonb(new)->'key')is distinct from(to_jsonb(old)->'key')or tg_table_name='partner_territories'and(to_jsonb(new)-'status')is distinct from(to_jsonb(old)-'status')then raise exception'Exact partner anchors retained'using errcode='23514';end if;return new;
end$$;
create function boss_private.partner_row_contract()returns trigger language plpgsql volatile security definer set search_path=''as $$begin
 if tg_table_name='partner_config_revisions'then if not exists(select 1 from public.modules where id=new.module_id and key='commerce')then raise exception'Commerce anchor required'using errcode='23514';end if;end if;
 if tg_table_name='partner_contract_revisions'then if exists(select 1 from unnest(new.countries)country where country!~'^[A-Z]{2}$')then raise exception'Country codes required'using errcode='23514';end if;end if;
 return new;end$$;
create trigger partner_configuration_contract before insert on public.partner_config_revisions for each row execute function boss_private.partner_row_contract();
create trigger partner_licensing_contract before insert on public.partner_contract_revisions for each row execute function boss_private.partner_row_contract();
do $$declare t text;s text;begin
 foreach s in array array['public','boss_private']loop
 for t in select tablename from pg_tables where schemaname=s and tablename like'partner_%'loop
 execute format('alter table %I.%I enable row level security',s,t);
 execute format('revoke all on %I.%I from public,anon,authenticated,service_role,boss_payment_worker',s,t);
 if t not in('partner_providers','partner_benefit_sources','partner_territories','partner_import_runs','partner_catalog_snapshots')then
 execute format('create trigger %I before update or delete on %I.%I for each row execute function boss_private.partner_immutable()',t||'_immutable',s,t);
 execute format('create trigger %I before truncate on %I.%I for each statement execute function boss_private.partner_immutable()',t||'_no_truncate',s,t);
 elsif t<>'partner_import_runs'then
 execute format('create trigger %I before update or delete on %I.%I for each row execute function boss_private.partner_anchor()',t||'_anchor',s,t);
 execute format('create trigger %I before truncate on %I.%I for each statement execute function boss_private.partner_anchor()',t||'_no_truncate',s,t);
 end if;end loop;end loop;
end$$;
-- Exact helper grants: public RPCs are invokers over only two caller-bound helpers.
do $$declare f record;begin for f in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'partner_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',f.signature);end loop;end$$;
revoke all on function public.boss_partners_mutate(jsonb),public.boss_partners_read(jsonb),public.boss_partners_directory()from public,anon,authenticated,service_role,boss_payment_worker;
grant execute on function boss_private.partner_mutate(jsonb),boss_private.partner_read(jsonb),public.boss_partners_mutate(jsonb),public.boss_partners_read(jsonb)to authenticated;
grant execute on function public.boss_partners_directory()to anon,authenticated;
-- New FK lookup indexes, including audit/history and composite resource anchors.
create index partner_provider_creator_idx on public.partner_providers(created_by);
create index partner_config_creator_idx on public.partner_config_revisions(created_by);
create index partner_config_module_idx on public.partner_config_revisions(module_id);
create index partner_provider_event_actor_idx on public.partner_provider_events(actor_id);
create index partner_contract_creator_idx on public.partner_contract_revisions(created_by);
create index partner_contract_product_idx on public.partner_contract_revisions(product_id);
create index partner_contract_event_actor_idx on public.partner_contract_events(actor_id);
create index partner_territory_creator_idx on public.partner_territories(created_by);
create index partner_territory_market_idx on public.partner_territories(market_id);
create index partner_catalog_contract_idx on public.partner_benefit_revisions(contract_id);
create index partner_catalog_product_idx on public.partner_benefit_revisions(product_id);
create index partner_catalog_market_idx on public.partner_benefit_revisions(market_id);
create index partner_review_actor_idx on public.partner_benefit_reviews(actor_id);
create index partner_import_actor_idx on public.partner_import_runs(actor_id);
create index partner_policy_creator_idx on public.partner_commission_policies(created_by);
create index partner_transaction_revision_idx on public.partner_transaction_sources(benefit_revision_id);
create index partner_transaction_creator_idx on public.partner_transaction_sources(created_by);
create index partner_event_actor_idx on public.partner_transaction_events(actor_id);
create unique index partner_event_corrects_idx on public.partner_transaction_events(corrects_event_id);
create index partner_receipt_provider_idx on boss_private.partner_receipts(provider_id);
create index partner_contract_event_anchor_idx on public.partner_contract_events(provider_id,contract_id);
create index partner_territory_anchor_idx on public.partner_territories(provider_id,contract_id);
create index partner_catalog_source_anchor_idx on public.partner_benefit_revisions(provider_id,source_id);
create index partner_catalog_contract_anchor_idx on public.partner_benefit_revisions(provider_id,contract_id);
create index partner_review_anchor_idx on public.partner_benefit_reviews(provider_id,revision_id);
create index partner_snapshot_provider_idx on public.partner_catalog_snapshots(provider_id);
create index partner_policy_anchor_idx on public.partner_commission_policies(provider_id,contract_id);
create index partner_transaction_benefit_anchor_idx on public.partner_transaction_sources(provider_id,benefit_revision_id);
create index partner_transaction_policy_anchor_idx on public.partner_transaction_sources(provider_id,policy_id);
create index partner_event_anchor_idx on public.partner_transaction_events(provider_id,transaction_id);
