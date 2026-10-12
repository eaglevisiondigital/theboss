create function boss_private.merchant_command_keys(action text)returns text[]language sql immutable set search_path=''as $$select case action
 when'category.configure'then array['key','name','status']
 when'market.create'then array['country','region','market']
 when'merchant.create'then array['name','legal_name','description','category','market_id','website','public_phone','controlled']
 when'claim.submit'then array['merchant_id','statement']when'claim.review'then array['merchant_id','claim_id','state','reason','ends_at']
 when'merchant.review'then array['merchant_id','state','reason']when'merchant.configure'then array['merchant_id','status','portal','offers','redemption','ends_at']
 when'merchant.edit'then array['merchant_id','expected_version','name','description','website','public_phone']
 when'access.grant'then array['merchant_id','location_id','person_id','role','ends_at']when'access.end'then array['merchant_id','assignment_id']
 when'staff.grant'then array['merchant_id','person_id','role','ends_at']when'staff.end'then array['merchant_id','assignment_id']
 when'location.create'then array['merchant_id','market_id','name','address','city','postal_code','timezone','phone','website','hours_note']
 when'location.edit'then array['merchant_id','location_id','expected_version','name','hours_note','status']
 when'family.create'then array['merchant_id','location_id','usage_limit','reset_period','usage_timezone','period_start','period_end']when'family.status'then array['merchant_id','family_id','status']
 when'offer.create'then array['merchant_id','family_id','title','description','offer_type','discount_bps','currency','amount_minor','buy_quantity','benefit_quantity','purchase_description','benefit_description','qualification','minimum_minor','qualifying_description','exclusions','stacking','stacking_policy','starts_at','ends_at','weekdays','local_start','local_end','weekly_special','location_policy','location_ids','include_future','allow_local_pause']
 when'offer.status'then array['merchant_id','location_id','revision_id','state','reason']when'offer.local'then array['merchant_id','family_id','location_id','paused','presentation_note']
 when'intent.create'then array['merchant_id','location_id','revision_id','capability']when'token.verify'then array['merchant_id','location_id','capability']when'token.redeem'then array['merchant_id','location_id','capability']
 when'redemption.correct'then array['merchant_id','redemption_id','reason','restore_allowance']
 when'sales.grant'then array['person_id','role','market_id','manager_id','ends_at']when'sales.end'then array['assignment_id']
 when'lead.create'then array['market_id','name','category','source','rep_id','manager_id']when'lead.activity'then array['lead_id','kind','note','due_at']
 when'lead.state'then array['lead_id','expected_version','state']when'lead.reassign'then array['lead_id','expected_version','rep_id','manager_id']when'lead.convert'then array['lead_id','expected_version','controlled']
 when'favorite.set'then array['merchant_id','favorite']end$$;
create function boss_private.merchant_required_keys(action text)returns text[]language sql immutable set search_path=''as $$select case action
 when'category.configure'then array['key','name','status']
 when'market.create'then array['country','region','market']
 when'merchant.create'then array['name','category','market_id']
 when'claim.submit'then array['merchant_id','statement']
 when'claim.review'then array['merchant_id','claim_id','state','reason']
 when'merchant.review'then array['merchant_id','state','reason']
 when'merchant.configure'then array['merchant_id','status']
 when'merchant.edit'then array['merchant_id','expected_version']
 when'access.grant'then array['merchant_id','person_id','role']
 when'access.end'then array['merchant_id','assignment_id']
 when'staff.grant'then array['merchant_id','person_id','role']
 when'staff.end'then array['merchant_id','assignment_id']
 when'location.create'then array['merchant_id','market_id','name','address','city','postal_code','timezone']
 when'location.edit'then array['merchant_id','location_id','expected_version']
 when'family.create'then array['merchant_id','reset_period','usage_timezone']
 when'family.status'then array['merchant_id','family_id','status']
 when'offer.create'then array['merchant_id','family_id','title','offer_type','qualification','stacking','starts_at','ends_at','location_policy']
 when'offer.status'then array['merchant_id','revision_id','state']
 when'offer.local'then array['merchant_id','family_id','location_id','paused']
 when'intent.create'then array['merchant_id','location_id','revision_id','capability']
 when'token.verify'then array['merchant_id','location_id','capability']
 when'token.redeem'then array['merchant_id','location_id','capability']
 when'redemption.correct'then array['merchant_id','redemption_id','reason']
 when'sales.grant'then array['person_id','role','market_id']
 when'sales.end'then array['assignment_id']
 when'lead.create'then array['market_id','name','category','source']
 when'lead.activity'then array['lead_id','kind','note']
 when'lead.state'then array['lead_id','expected_version','state']
 when'lead.reassign'then array['lead_id','expected_version','rep_id']
 when'lead.convert'then array['lead_id','expected_version']
 when'favorite.set'then array['merchant_id','favorite']
end$$;
create function boss_private.merchant_replay_allowed(actor uuid,r boss_private.merchant_receipts)returns boolean language plpgsql volatile security definer set search_path=''as $$
declare t boss_private.merchant_redemption_intents;l public.merchant_sales_leads;begin
 if r.permission_key='platform'then return boss_private.merchant_platform(actor,'merchant_reviews.manage');
 elsif r.permission_key='platform_sales'then return boss_private.merchant_platform(actor,'merchant_sales.manage');
 elsif r.permission_key='self'then return boss_private.rails_actor_current(actor);
 elsif r.permission_key='sales'then select *into l from public.merchant_sales_leads where id=(r.result->>'lead_id')::uuid;return boss_private.merchant_sales_can(actor,l.market_id,l.rep_id);
 elsif r.permission_key='consumer'then select *into t from boss_private.merchant_redemption_intents where id=(r.result->>'intent_id')::uuid;
 return t.person_id=actor and t.retired_at is null and t.consumed_at is null and t.expires_at>clock_timestamp()and boss_private.discount_source_valid(t.source_id)
 and boss_private.merchant_membership_source(actor,t.location_id)is not null and boss_private.merchant_available(t.revision_id,t.location_id)and boss_private.merchant_feature(t.merchant_id,'redemption');
 else return boss_private.merchant_can(actor,r.permission_key,r.merchant_id,r.location_id);end if;
end$$;
create function boss_private.merchant_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;i jsonb:=command->'input';action text:=command->>'action';request uuid:=(command->>'request_id')::uuid;
 m uuid:=(i->>'merchant_id')::uuid;loc uuid;k text;digest text;r boss_private.merchant_receipts;result jsonb;begin
 perform boss_private.require_live_auth();actor:=boss_private.current_person_id();
 if actor is null or not boss_private.rails_actor_current(actor)then raise exception'Access denied'using errcode='PT403';end if;
 if request is null or jsonb_typeof(command)is distinct from'object'or command-'input'-'action'-'request_id'<>'{}'::jsonb
 or jsonb_typeof(i)is distinct from'object'or octet_length(command::text)>32000 or boss_private.merchant_command_keys(action)is null
 or exists(select 1 from unnest(boss_private.merchant_required_keys(action))key where not i?key or i->key='null'::jsonb)
 or exists(select 1 from jsonb_object_keys(i)as keys(key_value)where not keys.key_value=any(boss_private.merchant_command_keys(action)))then raise exception'Finite merchant command required'using errcode='PT422';end if;
 if exists(select 1 from jsonb_each(i)e where jsonb_typeof(e.value)='string'and(length(e.value#>>'{}')>1500 or(e.value#>>'{}')~'[<>\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'))then raise exception'Bounded plain text required'using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-merchant-request:'||actor||':'||request,0));perform boss_private.merchant_fence(actor,m);
 digest:=encode(sha256(convert_to(command::text,'UTF8')),'hex');select *into r from boss_private.merchant_receipts where actor_id=actor and request_id=request;
 if r.actor_id is not null then
 if r.command_digest<>digest then raise exception'Request already bound to another command'using errcode='PT409';end if;
 if not boss_private.merchant_replay_allowed(actor,r)then raise exception'Current merchant scope required'using errcode='PT403';end if;
 if action='token.verify'then
 result:=boss_private.merchant_redemption_operate(actor,action,i,request);
 return(result-'_permission'-'_location')||jsonb_build_object('action',action,'replayed',true);
 end if;
 return r.result||jsonb_build_object('replayed',true);end if;
 if action like'sales.%'or action like'lead.%'then result:=boss_private.merchant_sales_operate(actor,action,i,request);
 elsif action in('intent.create','token.verify','token.redeem','redemption.correct')then result:=boss_private.merchant_redemption_operate(actor,action,i,request);
 elsif action='favorite.set'then
 if not exists(select 1 from public.merchants where id=m and status='active')then raise exception'Merchant unavailable'using errcode='PT404';end if;
 if(i->>'favorite')::boolean then insert into public.merchant_favorites(person_id,merchant_id)values(actor,m)on conflict do nothing;else delete from public.merchant_favorites where person_id=actor and merchant_id=m;end if;
 result:=jsonb_build_object('merchant_id',m,'_permission','self');
 else result:=boss_private.merchant_operate(actor,action,i,request);end if;
 k:=result->>'_permission';loc:=coalesce((result->>'_location')::uuid,(i->>'location_id')::uuid);m:=coalesce((result->>'merchant_id')::uuid,m);
 result:=(result-'_permission'-'_location')||jsonb_build_object('action',action,'replayed',false);
 insert into boss_private.merchant_receipts(actor_id,request_id,action,merchant_id,location_id,permission_key,command_digest,result)values(actor,request,action,m,loc,k,digest,result);
 return result;
end$$;
create schema boss_merchants_public;
revoke all on schema boss_merchants_public from public,anon,authenticated,service_role,boss_payment_worker;
grant usage on schema boss_merchants_public to anon,authenticated;
create function boss_merchants_public.options(query jsonb default '{}')returns jsonb language sql stable security definer set search_path=''as $$
 select jsonb_build_object('markets',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'country',g.country,'region',g.region,'market',g.market))from(
 select *from public.merchant_markets where status='active'and(id=(query->>'market_id')::uuid or
 (coalesce(query->>'market_search','')=''or lower(market)like lower(query->>'market_search')||'%')and(query->>'market_after'is null or id>(query->>'market_after')::uuid))
 order by (id=(query->>'market_id')::uuid)desc nulls last,id limit 50)g),'[]'::jsonb),
 'categories',coalesce((select jsonb_agg(jsonb_build_object('key',key,'name',name))from(select *from public.merchant_categories where status='active'order by key limit 50)c),'[]'::jsonb))
$$;
create function boss_merchants_public.directory(query jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare market uuid:=(query->>'market_id')::uuid;after uuid:=coalesce((query->>'directory_after')::uuid,(query->>'after')::uuid);n integer:=coalesce((query->>'limit')::integer,30);category text:=query->>'category';search text:=coalesce(query->>'search','');items jsonb;begin
 if query-'market_id'-'after'-'limit'-'category'-'search'-'market_search'-'market_after'-'directory_after'<>'{}'::jsonb or n not between 1 and 50 or length(search)>80 or search~'[%_<>]'or length(coalesce(query->>'market_search',''))>80 or coalesce(query->>'market_search','')~'[%_<>]'then raise exception'Bounded directory query required'using errcode='PT422';end if;
 -- Explicit market is required for consumer national-scale directory lookup.
 if market is null then return boss_merchants_public.options(query)||jsonb_build_object('items','[]'::jsonb);end if;
 select coalesce(jsonb_agg(x),'[]'::jsonb)into items from(select jsonb_build_object('id',m.id,'name',m.name,'description',m.description,'category',m.category,'website',m.website,'public_phone',m.public_phone,'logo_ref',m.logo_ref,
 'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'address',l.address,'city',l.city,'postal_code',l.postal_code,'country',g.country,'region',g.region,'market',g.market,'timezone',l.timezone,'phone',l.phone,'website',l.website,'hours_note',l.hours_note)),'[]'::jsonb)
 from(select *from public.merchant_locations where merchant_id=m.id and market_id=market and status='active'order by id limit 30)l join public.merchant_markets g on g.id=l.market_id),
 'network_available',boss_private.merchant_feature(m.id,'offers'))x
 from public.merchants m where m.status='active'and exists(select 1 from public.merchant_locations l join public.merchant_markets g on g.id=l.market_id and g.status='active'where l.merchant_id=m.id and l.market_id=market and l.status='active')
 and(category is null or m.category=category)and(search=''or lower(m.name)like lower(search)||'%')and(after is null or m.id>after)order by m.id limit n)q;
 return boss_merchants_public.options(query)||jsonb_build_object('items',items,'has_more',jsonb_array_length(items)=n);
end$$;
create function boss_private.merchant_read(query jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare actor uuid;mode text:=coalesce(query->>'mode','consumer');m uuid:=(query->>'merchant_id')::uuid;loc uuid:=(query->>'location_id')::uuid;
 market uuid:=(query->>'market_id')::uuid;after uuid:=(query->>'after')::uuid;after_loc uuid:=(query->>'after_location_id')::uuid;n integer:=coalesce((query->>'limit')::integer,30);data jsonb;offers jsonb:='[]';leads jsonb;candidate record;platform_sales boolean;platform_portal boolean;begin
 perform boss_private.require_live_auth();actor:=boss_private.current_person_id();if actor is null or not boss_private.rails_actor_current(actor)then raise exception'Access denied'using errcode='PT403';end if;
 if query-'mode'-'merchant_id'-'location_id'-'market_id'-'after'-'after_location_id'-'limit'-'category'-'search'-'favorites'-'offer_type'-'market_search'-'market_after'-'directory_after'<>'{}'::jsonb or n not between 1 and 50 or mode not in('consumer','portal','sales')then raise exception'Finite merchant query required'using errcode='PT422';end if;
 if mode='consumer'then
 data:=boss_merchants_public.directory(query-'mode'-'merchant_id'-'location_id'-'favorites'-'offer_type'-'after_location_id'-'after');
 -- Geography and current membership are checked once per selected market.
 -- Ordered candidates use cheap indexed predicates; only candidates that are
 -- emitted evaluate the full current offer/role/evidence projection.
 if boss_private.merchant_market_source(actor,market)is not null then
 for candidate in select r.id revision_id,l.id location_id from public.merchant_locations l
 join public.merchants b on b.id=l.merchant_id and b.status='active'
 join public.merchant_modules cfg on cfg.merchant_id=b.id and cfg.status='active'and cfg.starts_at<=clock_timestamp()and(cfg.ends_at is null or cfg.ends_at>clock_timestamp())and cfg.configuration->'offers'='true'::jsonb
 join public.modules catalog on catalog.id=cfg.module_id and catalog.key='commerce'and catalog.status='active'
 join public.merchant_offer_revisions r on r.merchant_id=b.id
 join public.merchant_offer_families f on f.id=r.family_id and f.status='active'
 join lateral(select state from public.merchant_offer_events e where e.revision_id=r.id order by created_at desc,id desc limit 1)e on e.state in('scheduled','published')
 where l.market_id=market and l.status='active'and r.starts_at<=clock_timestamp()and r.ends_at>clock_timestamp()
 and(m is null or b.id=m)and(loc is null or l.id=loc)and(after is null or(r.id,l.id)>(after,coalesce(after_loc,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
 and(query->>'category'is null or b.category=query->>'category')and(query->>'offer_type'is null or r.offer_type=query->>'offer_type')
 and(coalesce(query->>'search','')=''or lower(b.name)like lower(query->>'search')||'%')
 and(not coalesce((query->>'favorites')::boolean,false)or exists(select 1 from public.merchant_favorites fav where fav.person_id=actor and fav.merchant_id=b.id))order by r.id,l.id
 loop
 if not boss_private.merchant_available(candidate.revision_id,candidate.location_id)then continue;end if;
 select jsonb_build_object('merchant_id',r.merchant_id,'merchant_name',b.name,'location_id',l.id,'location_name',l.name,'revision_id',r.id,'family_id',f.id,
 'presentation_note',coalesce((select presentation_note from public.merchant_offer_local_state s where s.family_id=f.id and s.location_id=l.id),''),'timezone',l.timezone,'weekly_special',r.weekly_special,'weekdays',r.weekdays,'local_start',r.local_start,'local_end',r.local_end,'starts_at',r.starts_at,'ends_at',r.ends_at,
 'terms',boss_private.merchant_terms(r),'usage_limit',f.usage_limit,'reset_period',f.reset_period,'remaining_uses',case when f.usage_limit is null then null else greatest(0,f.usage_limit-boss_private.merchant_usage(actor,f.id,boss_private.merchant_window(f)))end,
 'can_redeem',boss_private.merchant_can(actor,'merchant_redemptions.manage',b.id,l.id),'availability',case when f.usage_limit is not null and boss_private.merchant_usage(actor,f.id,boss_private.merchant_window(f))>=f.usage_limit then'usage_limit_reached'else'eligible'end)
 into data from public.merchant_offer_revisions r join public.merchant_offer_families f on f.id=r.family_id join public.merchants b on b.id=r.merchant_id join public.merchant_locations l on l.id=candidate.location_id where r.id=candidate.revision_id;
 offers:=offers||jsonb_build_array(data);exit when jsonb_array_length(offers)>=n;
 end loop;end if;
 data:=boss_merchants_public.directory(query-'mode'-'merchant_id'-'location_id'-'favorites'-'offer_type'-'after_location_id'-'after');
 if boss_private.merchant_market_source(actor,market)is null then offers:='[]';end if;
 return data||jsonb_build_object('mode',mode,'offers',offers,'offers_has_more',jsonb_array_length(offers)=n,'membership_required',boss_private.merchant_market_source(actor,market)is null,'availability',case when market is null then'choose_market'when boss_private.merchant_market_source(actor,market)is not null then case when jsonb_array_length(offers)=0 then case
 when loc is not null and exists(select 1 from public.merchant_locations l join public.merchants b on b.id=l.merchant_id and b.status='active'where l.id=loc and l.status='active'and l.market_id<>market)then'outside_location_or_market'
 when m is not null and exists(select 1 from public.merchant_offer_revisions r where r.merchant_id=m and r.ends_at<=clock_timestamp()and boss_private.merchant_offer_state(r.id)in('published','scheduled'))then'offer_expired'else'offer_unavailable'end else'eligible'end when not exists(select 1 from public.discount_memberships d where(d.subject_type='person'and d.subject_id=actor or d.subject_type='household'and d.subject_id in(select household_id from public.household_memberships where person_id=actor and status='active'))and boss_private.discount_subject(actor,d.subject_type,d.subject_id)and exists(select 1 from public.discount_member_sources src where src.membership_id=d.id and boss_private.discount_source_valid(src.id)))then case when exists(select 1 from public.discount_memberships d join public.discount_member_sources src on src.membership_id=d.id where(d.subject_type='person'and d.subject_id=actor or d.subject_type='household'and d.subject_id in(select household_id from public.household_memberships where person_id=actor and status='active'))and boss_private.discount_subject(actor,d.subject_type,d.subject_id)and src.ends_at<=clock_timestamp()and not exists(select 1 from public.discount_source_revocations v where v.source_id=src.id))then'membership_expired'else'membership_required'end else'outside_membership_coverage'end,
 'history',coalesce((select jsonb_agg(jsonb_build_object('id',id,'merchant_id',merchant_id,'location_id',location_id,'title',terms_snapshot->>'title','created_at',created_at,'corrected',exists(select 1 from public.merchant_redemption_corrections where redemption_id=r.id)))from(select *from public.merchant_redemptions where person_id=actor order by created_at desc,id desc limit 30)r),'[]'::jsonb));
 elsif mode='sales'then
 platform_sales:=boss_private.merchant_platform(actor,'merchant_sales.manage');
 select coalesce(jsonb_agg(x),'[]'::jsonb)into leads from(select jsonb_build_object('id',l.id,'name',l.name,'market_id',l.market_id,'state',l.state,'source',l.source,'rep_id',l.rep_id,'manager_id',l.manager_id,'merchant_id',l.merchant_id,'version',l.version,'can_reassign',platform_sales or exists(select 1 from public.merchant_sales_assignments a join public.roles ar on ar.id=a.role_id and ar.key='regional_manager'where a.person_id=actor and a.market_id=l.market_id and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())),
 'activities',coalesce((select jsonb_agg(jsonb_build_object('id',id,'kind',kind,'note',note,'due_at',due_at))from(select *from public.merchant_sales_activities where lead_id=l.id order by created_at desc,id desc limit 10)a),'[]'::jsonb))x
 from public.merchant_sales_leads l where(market is null or l.market_id=market)and(after is null or l.id>after)and(platform_sales or exists(select 1 from public.merchant_sales_assignments a join public.roles ar on ar.id=a.role_id and ar.status='active'
 join public.role_permissions rp on rp.role_id=ar.id join public.permissions ap on ap.id=rp.permission_id and ap.key='merchant_sales.manage'and ap.status='active'
 where a.person_id=actor and a.market_id=l.market_id and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())
 and(ar.key='sales_rep'and l.rep_id=actor or ar.key='regional_manager'and exists(select 1 from public.merchant_sales_assignments ra join public.roles rr on rr.id=ra.role_id and rr.key='sales_rep'and rr.status='active'
 where ra.person_id=l.rep_id and ra.manager_id=actor and ra.market_id=l.market_id and ra.status='active'and ra.starts_at<=clock_timestamp()and(ra.ends_at is null or ra.ends_at>clock_timestamp())))))order by l.id limit n)q;
 return (boss_merchants_public.options('{}')-'markets')||jsonb_build_object('mode',mode,'leads',leads,'can_assign',boss_private.merchant_platform(actor,'merchant_sales.manage'),'can_create',boss_private.merchant_platform(actor,'merchant_sales.manage')or exists(select 1 from public.merchant_sales_assignments a where a.person_id=actor and boss_private.merchant_sales_can(actor,a.market_id)),
 'markets',coalesce((select jsonb_agg(jsonb_build_object('id',id,'market',market,'region',region,'country',country))from(select *from public.merchant_markets g where status='active'and boss_private.merchant_sales_can(actor,g.id)order by id limit 50)g),'[]'::jsonb));
 end if;
 platform_portal:=boss_private.merchant_platform(actor,'merchants.view');
 if m is null then return boss_merchants_public.options(query)||jsonb_build_object('mode',mode,'merchants',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'status',status,'preferred_location_id',(select a.location_id from public.merchant_access_assignments a where a.merchant_id=b.id and a.person_id=actor and a.status='active'and a.location_id is not null and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())order by a.id limit 1)))from(select *from public.merchants b where(after is null or b.id>after)and(platform_portal or b.created_by=actor
 or b.id in(select merchant_id from public.merchant_claims where person_id=actor)
 or b.id in(select merchant_id from public.merchant_access_assignments where person_id=actor and status='active'and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp()))
 or b.id in(select merchant_id from public.merchant_staff_assignments where person_id=actor and status='active'and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp())))and(
 boss_private.merchant_can(actor,'merchants.view',b.id)or b.created_by=actor or exists(select 1 from public.merchant_claims c where c.person_id=actor and c.merchant_id=b.id)
 or exists(select 1 from public.merchant_access_assignments a where a.person_id=actor and a.merchant_id=b.id and a.location_id is not null and boss_private.merchant_can(actor,'merchant_offers.view',b.id,a.location_id)))order by id limit n)b),'[]'::jsonb),
 'markets',coalesce((select jsonb_agg(jsonb_build_object('id',id,'country',country,'region',region,'market',market))from(select *from public.merchant_markets where status='active'order by id limit 50)g),'[]'::jsonb),'can_market',boss_private.merchant_platform(actor,'merchant_reviews.manage'));
 end if;
 if not boss_private.merchant_can(actor,'merchants.view',m,loc)and not boss_private.merchant_can(actor,'merchant_offers.view',m,loc)
 and not exists(select 1 from public.merchants where id=m and created_by=actor)and not exists(select 1 from public.merchant_claims where merchant_id=m and person_id=actor)then raise exception'Merchant scope restricted'using errcode='PT403';end if;
 return boss_merchants_public.options(query)||jsonb_build_object('mode',mode,'merchant',(select jsonb_build_object('id',id,'name',name,'description',description,'status',status,'claim_state',claim_state,'category',category,'version',version,'website',website,'public_phone',public_phone)from public.merchants where id=m),
 'markets',coalesce((select jsonb_agg(jsonb_build_object('id',id,'country',country,'region',region,'market',market))from(select *from public.merchant_markets where status='active'order by id limit 50)g),'[]'::jsonb),
 'families',coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'usage_limit',f.usage_limit,'reset_period',f.reset_period,'usage_timezone',f.usage_timezone,'status',f.status))from(select *from public.merchant_offer_families f where merchant_id=m and(boss_private.merchant_can(actor,'merchant_offers.manage',m)or boss_private.merchant_can(actor,'merchant_offers.manage',m,loc)and(f.created_by=actor or exists(select 1 from public.merchant_offer_revisions r join public.merchant_offer_locations t on t.revision_id=r.id where r.family_id=f.id and t.location_id=loc)))order by id limit 50)f),'[]'::jsonb),
 'can_manage',boss_private.merchant_can(actor,'merchants.manage',m),'can_access',boss_private.merchant_can(actor,'merchants.access_manage',m),'can_locations',boss_private.merchant_can(actor,'merchant_locations.manage',m,loc),
 'can_offers',boss_private.merchant_can(actor,'merchant_offers.manage',m,loc),'can_review',boss_private.merchant_can(actor,'merchant_reviews.manage',m),'can_configure',boss_private.merchant_platform(actor,'merchant_reviews.manage'),
 'can_redeem',boss_private.merchant_can(actor,'merchant_redemptions.manage',m,loc),
 'claims',coalesce((select jsonb_agg(jsonb_build_object('id',id,'state',state,'statement',statement,'person_id',person_id,'created_at',created_at))from(select *from public.merchant_claims where merchant_id=m and(boss_private.merchant_can(actor,'merchant_reviews.manage',m)or person_id=actor)order by created_at desc limit 20)c),'[]'::jsonb),
 'locations',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'address',l.address,'city',l.city,'postal_code',l.postal_code,'timezone',l.timezone,'market_id',l.market_id,'status',l.status,'version',l.version))from(select *from public.merchant_locations l where merchant_id=m and(loc is null or id=loc)
 and(boss_private.merchant_can(actor,'merchant_locations.view',m,l.id)or boss_private.merchant_can(actor,'merchant_offers.view',m,l.id))order by id limit 50)l),'[]'::jsonb),
 'offers',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'family_id',r.family_id,'revision',r.revision,'state',case when r.ends_at<=clock_timestamp()and boss_private.merchant_offer_state(r.id)in('published','scheduled')then'expired'else boss_private.merchant_offer_state(r.id)end,'terms',boss_private.merchant_terms(r),'starts_at',r.starts_at,'ends_at',r.ends_at,'weekdays',r.weekdays,'local_start',r.local_start,'local_end',r.local_end,'weekly_special',r.weekly_special,'include_future',r.include_future,'can_global_edit',boss_private.merchant_can(actor,'merchant_offers.manage',m)or loc is not null and boss_private.merchant_can(actor,'merchant_offers.manage',m,loc)and not r.include_future and(select count(*)from public.merchant_offer_locations t where t.revision_id=r.id)=1,
 'usage_limit',f.usage_limit,'reset_period',f.reset_period,'usage_timezone',f.usage_timezone))from(select *from public.merchant_offer_revisions r where merchant_id=m and(after is null or id>after)and(
 boss_private.merchant_can(actor,'merchant_offers.view',m)or loc is not null and boss_private.merchant_can(actor,'merchant_offers.view',m,loc)and exists(select 1 from public.merchant_offer_locations t where t.revision_id=r.id and t.location_id=loc))order by id limit n)r join public.merchant_offer_families f on f.id=r.family_id),'[]'::jsonb),
 'assignments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'person_id',a.person_id,'role',r.key,'location_id',a.location_id,'status',a.status,'ends_at',a.ends_at))from(select *from public.merchant_access_assignments where merchant_id=m and boss_private.merchant_can(actor,'merchants.access_manage',m)order by id limit 50)a join public.roles r on r.id=a.role_id),'[]'::jsonb),
 'redemptions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'location_id',location_id,'title',terms_snapshot->>'title','created_at',created_at,'corrected',exists(select 1 from public.merchant_redemption_corrections where redemption_id=r.id)))from(select *from public.merchant_redemptions r where merchant_id=m and(loc is null or location_id=loc)and(boss_private.merchant_can(actor,'merchant_redemptions.view',m,r.location_id)or boss_private.merchant_can(actor,'merchant_reviews.manage',m))order by created_at desc,id desc limit 30)r),'[]'::jsonb),
 'analytics',coalesce((select jsonb_agg(jsonb_build_object('location_id',location_id,'family_id',family_id,'day',bucket_day,'redemptions',redemptions))from(select location_id,family_id,date_trunc('day',created_at)bucket_day,count(*)redemptions from public.merchant_redemptions r where merchant_id=m and created_at>=clock_timestamp()-interval'90 days'and(loc is null or location_id=loc)and boss_private.merchant_can(actor,'merchant_redemptions.view',m,r.location_id)group by location_id,family_id,date_trunc('day',created_at)order by bucket_day desc limit 50)a),'[]'::jsonb));
end$$;
create function public.boss_merchants_read(query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.merchant_read(query)$$;
create function public.boss_merchants_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.merchant_mutate(command)$$;
create function public.boss_merchants_directory(query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_merchants_public.directory(query)$$;
