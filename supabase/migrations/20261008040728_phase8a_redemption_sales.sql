create table public.merchant_sales_assignments(
 id uuid primary key default gen_random_uuid(),person_id uuid not null references public.people(id),role_id uuid not null references public.roles(id),
 market_id uuid not null references public.merchant_markets(id),manager_id uuid references public.people(id),starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,
 status text not null default 'active'check(status in('active','ended')),granted_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)),check(manager_id is distinct from person_id));
create index merchant_sales_assignments_scope_idx on public.merchant_sales_assignments(person_id,market_id)where status='active';
create table public.merchant_sales_leads(
 id uuid primary key default gen_random_uuid(),market_id uuid not null references public.merchant_markets(id),name text not null check(length(btrim(name))between 1 and 120 and name!~'[<>]'),
 category text not null references public.merchant_categories(key),source text not null check(length(btrim(source))between 1 and 120 and source!~'[<>]'),
 rep_id uuid not null references public.people(id),manager_id uuid references public.people(id),state text not null default 'new'check(state in('new','contacted','interested','onboarding','submitted','approved','declined','inactive')),
 merchant_id uuid unique references public.merchants(id),version bigint not null default 1,created_at timestamptz not null default clock_timestamp(),converted_at timestamptz);
create index merchant_sales_leads_pipeline_idx on public.merchant_sales_leads(rep_id,market_id,state,id);
create index merchant_sales_leads_manager_idx on public.merchant_sales_leads(manager_id,market_id,id);
create table public.merchant_sales_activities(
 id uuid primary key default gen_random_uuid(),lead_id uuid not null references public.merchant_sales_leads(id),actor_id uuid not null references public.people(id),
 kind text not null check(kind in('call','email','meeting','follow_up','note','onboarding_assist')),
 note text not null check(length(btrim(note))between 1 and 1200 and note!~'[<>]'),due_at timestamptz,created_at timestamptz not null default clock_timestamp());
create index merchant_sales_activities_page_idx on public.merchant_sales_activities(lead_id,created_at desc,id desc);
create table public.merchant_sales_history(
 id uuid primary key default gen_random_uuid(),lead_id uuid not null references public.merchant_sales_leads(id),actor_id uuid not null references public.people(id),
 action text not null check(action in('created','state','reassigned','converted')),rep_id uuid not null references public.people(id),manager_id uuid references public.people(id),
 market_id uuid not null references public.merchant_markets(id),merchant_id uuid references public.merchants(id),source text not null,created_at timestamptz not null default clock_timestamp());
create index merchant_sales_history_page_idx on public.merchant_sales_history(lead_id,created_at desc,id desc);
create function boss_private.merchant_sales_can(actor uuid,market uuid,rep uuid default null)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.rails_actor_current(actor)and(boss_private.merchant_platform(actor,'merchant_sales.manage')or exists(
 select 1 from public.merchant_sales_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.status='active'and p.key='merchant_sales.manage'
 where a.person_id=actor and a.market_id=market and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())
 and(r.key='sales_rep'and(rep is null or rep=actor)or r.key='regional_manager'and(rep is null or exists(select 1 from public.merchant_sales_assignments b join public.roles br on br.id=b.role_id and br.key='sales_rep'and br.status='active'
 where b.person_id=rep and b.manager_id=actor and b.market_id=market and b.status='active'and b.starts_at<=clock_timestamp()and(b.ends_at is null or b.ends_at>clock_timestamp()))))))
$$;
create function boss_private.merchant_sales_operate(actor uuid,action text,i jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare l public.merchant_sales_leads;id uuid;market uuid:=(i->>'market_id')::uuid;rep uuid;manager uuid;merchant uuid;begin
 if action='sales.end'then select market_id into market from public.merchant_sales_assignments where id=(i->>'assignment_id')::uuid;
 elsif action like'lead.%'and action<>'lead.create'then select market_id into market from public.merchant_sales_leads where id=(i->>'lead_id')::uuid;end if;
 if market is null then raise exception'Sales resource unavailable'using errcode='PT404';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-merchant-sales-market:'||market,0));
 perform 1 from public.merchant_sales_assignments where market_id=market order by id for share;
 if action in('sales.grant','sales.end')then
 if not boss_private.merchant_platform(actor,'merchant_sales.manage')then raise exception'Sales assignment restricted'using errcode='PT403';end if;
 if action='sales.grant'then
 if i->>'role'not in('sales_rep','regional_manager')or not boss_private.rails_actor_current((i->>'person_id')::uuid)then raise exception'Exact sales assignment required'using errcode='PT422';end if;
 insert into public.merchant_sales_assignments(person_id,role_id,market_id,manager_id,granted_by,ends_at)select(i->>'person_id')::uuid,id,market,(i->>'manager_id')::uuid,actor,(i->>'ends_at')::timestamptz from public.roles where key=i->>'role'returning id into id;
 else update public.merchant_sales_assignments set status='ended'where id=(i->>'assignment_id')::uuid returning id into id;
 if id is null then raise exception'Sales assignment unavailable'using errcode='PT404';end if;end if;
 perform boss_private.merchant_audit(actor,null,'merchant.'||action,id,request);return jsonb_build_object('resource_id',id,'_permission','platform_sales');
 elsif action='lead.create'then
 rep:=coalesce((i->>'rep_id')::uuid,actor);manager:=(i->>'manager_id')::uuid;
 if not boss_private.merchant_sales_can(actor,market,rep)or not boss_private.merchant_sales_can(rep,market,rep)
 or manager is not null and not exists(select 1 from public.merchant_sales_assignments a join public.roles r on r.id=a.role_id and r.key='regional_manager'where a.person_id=manager and a.market_id=market and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()))then raise exception'Assigned sales scope required'using errcode='PT403';end if;
 insert into public.merchant_sales_leads(market_id,name,category,source,rep_id,manager_id)values(market,i->>'name',i->>'category',i->>'source',rep,manager)returning *into l;
 else select *into l from public.merchant_sales_leads where id=(i->>'lead_id')::uuid for update;
 if l.id is null or not boss_private.merchant_sales_can(actor,l.market_id,l.rep_id)then raise exception'Sales scope restricted'using errcode='PT403';end if;
 if action='lead.activity'then
 insert into public.merchant_sales_activities(lead_id,actor_id,kind,note,due_at)values(l.id,actor,i->>'kind',i->>'note',(i->>'due_at')::timestamptz)returning id into id;
 perform boss_private.merchant_audit(actor,l.merchant_id,'merchant.lead.activity',id,request);
 return jsonb_build_object('lead_id',l.id,'resource_id',id,'_permission','sales');
 end if;
 if(i->>'expected_version')is null or l.version<>(i->>'expected_version')::bigint then raise exception'Stale opportunity'using errcode='PT409';end if;
 if action='lead.reassign'then
 rep:=(i->>'rep_id')::uuid;manager:=(i->>'manager_id')::uuid;
 if not boss_private.merchant_platform(actor,'merchant_sales.manage')and not exists(select 1 from public.merchant_sales_assignments a join public.roles r on r.id=a.role_id and r.key='regional_manager'where a.person_id=actor and a.market_id=l.market_id and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()))then raise exception'Manager required'using errcode='PT403';end if;
 if not boss_private.merchant_sales_can(rep,l.market_id,rep)or manager is not null and not exists(select 1 from public.merchant_sales_assignments a join public.roles r on r.id=a.role_id and r.key='regional_manager'where a.person_id=manager and a.market_id=l.market_id and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()))then raise exception'Assigned rep/manager required'using errcode='PT403';end if;
 update public.merchant_sales_leads set rep_id=rep,manager_id=manager,version=version+1 where id=l.id returning *into l;
 elsif action='lead.state'then update public.merchant_sales_leads set state=i->>'state',version=version+1 where id=l.id returning *into l;
 elsif action='lead.convert'then
 if l.merchant_id is not null or l.state in('declined','inactive')then raise exception'Opportunity already converted or unavailable'using errcode='PT409';end if;
 insert into public.merchants(name,category,primary_market_id,created_by,controlled)values(l.name,l.category,l.market_id,actor,coalesce((i->>'controlled')::boolean,false))returning id into merchant;
 insert into public.merchant_modules(merchant_id,module_id)select merchant,id from public.modules where key='commerce';
 update public.merchant_sales_leads set merchant_id=merchant,converted_at=clock_timestamp(),state='submitted',version=version+1 where id=l.id returning *into l;
 else raise exception'Sales operation unavailable'using errcode='PT422';end if;
 end if;
 insert into public.merchant_sales_history(lead_id,actor_id,action,rep_id,manager_id,market_id,merchant_id,source)
 values(l.id,actor,case action when'lead.create'then'created'when'lead.reassign'then'reassigned'when'lead.convert'then'converted'else'state'end,l.rep_id,l.manager_id,l.market_id,l.merchant_id,l.source);
 perform boss_private.merchant_audit(actor,l.merchant_id,'merchant.'||action,l.id,request,jsonb_build_object('state',l.state));
 return jsonb_build_object('lead_id',l.id,'merchant_id',l.merchant_id,'version',l.version,'_permission','sales');
end$$;
create function boss_private.merchant_redemption_operate(actor uuid,action text,i jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare t boss_private.merchant_redemption_intents;r public.merchant_offer_revisions;f public.merchant_offer_families;s public.discount_member_sources;
 red public.merchant_redemptions;m uuid:=(i->>'merchant_id')::uuid;loc uuid:=(i->>'location_id')::uuid;proof text:=i->>'capability';usage_window text;uses bigint;id uuid;now_at timestamptz;begin
 if action='redemption.correct'then
 select *into red from public.merchant_redemptions where id=(i->>'redemption_id')::uuid and merchant_id=m;
 if red.id is null then raise exception'Redemption unavailable'using errcode='PT404';end if;
 perform boss_private.merchant_require(actor,'merchant_reviews.manage',m);
 insert into public.merchant_redemption_corrections(redemption_id,restore_allowance,reason,reviewer_id)values(red.id,coalesce((i->>'restore_allowance')::boolean,false),i->>'reason',actor)returning id into id;
 perform boss_private.merchant_audit(actor,m,'merchant.redemption.corrected',id,request,jsonb_build_object('redemption_id',red.id,'restore_allowance',coalesce((i->>'restore_allowance')::boolean,false)));
 return jsonb_build_object('redemption_id',red.id,'correction_id',id,'_permission','merchant_reviews.manage');
 end if;
 if proof is null or proof!~'^[a-f0-9]{64}$'then raise exception'Redemption proof required'using errcode='PT422';end if;
 if action='intent.create'then
 if(select count(*)from boss_private.merchant_redemption_intents where person_id=actor and consumed_at is null and retired_at is null and expires_at>clock_timestamp())>=20 then raise exception'Try later'using errcode='PT429';end if;
 select *into r from public.merchant_offer_revisions where id=(i->>'revision_id')::uuid and merchant_id=m;
 if r.id is null or not boss_private.merchant_available(r.id,loc)or not boss_private.merchant_feature(m,'redemption')then raise exception'Offer unavailable'using errcode='PT404';end if;
 select *into s from public.discount_member_sources where id=boss_private.merchant_membership_source(actor,loc);
 if s.id is null then raise exception'Membership scope required'using errcode='PT403';end if;
 perform 1 from public.discount_memberships where id=s.membership_id for update;
 perform 1 from public.discount_member_sources where membership_id=s.membership_id order by id for share;
 perform 1 from public.organization_modules where organization_id=s.organization_id order by id for share;
 select *into f from public.merchant_offer_families where id=r.family_id for update;
 usage_window:=boss_private.merchant_window(f);uses:=boss_private.merchant_usage(actor,f.id,usage_window);
 if f.usage_limit is not null and uses>=f.usage_limit then raise exception'Usage limit reached'using errcode='PT409';end if;
 now_at:=clock_timestamp();
 if not boss_private.merchant_available(r.id,loc,now_at)or not boss_private.discount_source_valid(s.id)or boss_private.merchant_membership_source(actor,loc)is null then raise exception'Current offer and membership required'using errcode='PT409';end if;
 insert into boss_private.merchant_redemption_intents(person_id,membership_id,source_id,merchant_id,location_id,family_id,revision_id,capability_digest,window_key,expires_at,created_at)
 values(actor,s.membership_id,s.id,m,loc,f.id,r.id,encode(sha256(convert_to(proof,'UTF8')),'hex'),usage_window,now_at+interval'5 minutes',now_at)returning id into id;
 perform boss_private.merchant_audit(actor,m,'merchant.redemption.intent',id,request,jsonb_build_object('location_id',loc,'revision_id',r.id));
 return jsonb_build_object('intent_id',id,'expires_at',now_at+interval'5 minutes','_permission','consumer','_location',loc);
 end if;
 perform boss_private.merchant_require(actor,'merchant_redemptions.manage',m,loc);
 select *into t from boss_private.merchant_redemption_intents where capability_digest=encode(sha256(convert_to(proof,'UTF8')),'hex')for update;
 if t.id is null or t.merchant_id<>m or t.location_id<>loc then raise exception'Redemption unavailable'using errcode='PT404';end if;
 if t.consumed_at is not null or t.retired_at is not null or t.expires_at<=clock_timestamp()then raise exception'Redemption expired or consumed'using errcode='PT409';end if;
 select *into r from public.merchant_offer_revisions where id=t.revision_id;
 perform boss_private.merchant_fence(t.person_id,m);
 perform 1 from public.discount_memberships where id=t.membership_id for update;
 perform 1 from public.discount_member_sources where membership_id=t.membership_id order by id for share;
 perform 1 from public.organization_modules where organization_id in(select organization_id from public.discount_member_sources where id=t.source_id)order by id for share;
 perform 1 from public.household_memberships where person_id=t.person_id and household_id in(select subject_id from public.discount_memberships where id=t.membership_id and subject_type='household')order by id for share;
 select *into f from public.merchant_offer_families where id=t.family_id for update;
 usage_window:=boss_private.merchant_window(f);uses:=boss_private.merchant_usage(t.person_id,f.id,usage_window);now_at:=clock_timestamp();
 if t.window_key<>usage_window or not boss_private.merchant_feature(m,'redemption')or not boss_private.merchant_available(r.id,loc,now_at)
 or not boss_private.rails_actor_current(t.person_id)or not boss_private.discount_source_valid(t.source_id)
 or not exists(select 1 from public.discount_memberships dm where dm.id=t.membership_id and boss_private.discount_subject(t.person_id,dm.subject_type,dm.subject_id))
 or boss_private.merchant_membership_source(t.person_id,loc)is null or not boss_private.merchant_can(actor,'merchant_redemptions.manage',m,loc)
 or t.expires_at<=now_at or f.usage_limit is not null and uses>=f.usage_limit then raise exception'Current redemption eligibility required'using errcode='PT409';end if;
 if action='token.verify'then return jsonb_build_object('valid',true,'title',r.title,'terms',boss_private.merchant_terms(r),'remaining_uses',case when f.usage_limit is null then null else f.usage_limit-uses end,'_permission','merchant_redemptions.manage','_location',loc);end if;
 if action<>'token.redeem'then raise exception'Redemption operation unavailable'using errcode='PT422';end if;
 update boss_private.merchant_redemption_intents set consumed_at=now_at where id=t.id;
 insert into public.merchant_redemptions(intent_id,person_id,membership_id,source_id,merchant_id,location_id,family_id,revision_id,window_key,clerk_id,terms_snapshot)
 values(t.id,t.person_id,t.membership_id,t.source_id,m,loc,f.id,r.id,usage_window,actor,boss_private.merchant_terms(r))returning id into id;
 perform boss_private.merchant_audit(actor,m,'merchant.redemption.recorded',id,request,jsonb_build_object('location_id',loc,'revision_id',r.id));
 return jsonb_build_object('redemption_id',id,'title',r.title,'terms',boss_private.merchant_terms(r),'remaining_uses',case when f.usage_limit is null then null else f.usage_limit-uses-1 end,'_permission','merchant_redemptions.manage','_location',loc);
end$$;
-- Safe operational terms omit author/consumer identifiers and proof digests.
create function boss_private.merchant_terms(r public.merchant_offer_revisions)returns jsonb language sql immutable set search_path=''as $$
 select jsonb_strip_nulls(jsonb_build_object('title',r.title,'description',r.description,'offer_type',r.offer_type,'discount_bps',r.discount_bps,'currency',r.currency,'amount_minor',r.amount_minor,
 'buy_quantity',r.buy_quantity,'benefit_quantity',r.benefit_quantity,'purchase_description',r.purchase_description,'benefit_description',r.benefit_description,
 'qualification',r.qualification,'minimum_minor',r.minimum_minor,'qualifying_description',r.qualifying_description,'exclusions',r.exclusions,'stacking',r.stacking,'stacking_policy',r.stacking_policy))
$$;
do $$declare t text;begin for t in select tablename from pg_tables where schemaname='public'and tablename like'merchant_%'loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);end loop;end$$;
