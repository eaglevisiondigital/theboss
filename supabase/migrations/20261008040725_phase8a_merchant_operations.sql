create function boss_private.merchant_operate(actor uuid,action text,i jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare m public.merchants;l public.merchant_locations;f public.merchant_offer_families;r public.merchant_offer_revisions;
 c public.merchant_claims;a public.merchant_access_assignments;id uuid;loc uuid:=(i->>'location_id')::uuid;k text;state text;role uuid;oldstate text;begin
 if action='category.configure'then
 if not boss_private.merchant_platform(actor,'merchant_reviews.manage')then raise exception'Platform review required'using errcode='PT403';end if;
 insert into public.merchant_categories(key,name,status)values(i->>'key',i->>'name',i->>'status')on conflict(key)do update set name=excluded.name,status=excluded.status;
 perform boss_private.merchant_audit(actor,null,'merchant.category.configured',null,request,jsonb_build_object('category_key',i->>'key'));
 return jsonb_build_object('_permission','platform');
 elsif action='market.create'then
 if not boss_private.merchant_platform(actor,'merchant_reviews.manage')then raise exception'Platform review required'using errcode='PT403';end if;
 insert into public.merchant_markets(country,region,market)values(i->>'country',i->>'region',i->>'market')returning id into id;
 return jsonb_build_object('market_id',id,'_permission','platform');
 elsif action='merchant.create'then
 if(select count(*)from public.merchants where created_by=actor and created_at>clock_timestamp()-interval'1 day')>=100 then raise exception'Try later'using errcode='PT429';end if;
 if not exists(select 1 from public.merchant_markets where id=(i->>'market_id')::uuid and status='active')or not exists(select 1 from public.merchant_categories where key=i->>'category'and status='active')then raise exception'Approved market and category required'using errcode='PT422';end if;
 insert into public.merchants(name,legal_name,description,category,primary_market_id,website,public_phone,created_by,controlled)
 values(i->>'name',i->>'legal_name',coalesce(i->>'description',''),i->>'category',(i->>'market_id')::uuid,i->>'website',i->>'public_phone',actor,coalesce((i->>'controlled')::boolean,false))returning *into m;
 insert into public.merchant_modules(merchant_id,module_id)select m.id,id from public.modules where key='commerce';
 perform boss_private.merchant_audit(actor,m.id,'merchant.created',m.id,request);return jsonb_build_object('merchant_id',m.id,'version',m.version,'_permission','self');
 end if;
 select *into m from public.merchants where id=(i->>'merchant_id')::uuid for update;
 if m.id is null then raise exception'Merchant unavailable'using errcode='PT404';end if;
 if action='claim.submit'then
 if m.claim_state<>'unclaimed'or m.status in('archived','suspended')then raise exception'Claim unavailable'using errcode='PT409';end if;
 insert into public.merchant_claims(merchant_id,person_id,statement)values(m.id,actor,i->>'statement')returning id into id;k:='self';
 elsif action='claim.review'then
 k:='merchant_reviews.manage';perform boss_private.merchant_require(actor,k,m.id);
 select *into c from public.merchant_claims where id=(i->>'claim_id')::uuid and merchant_id=m.id for update;
 if c.id is null or c.state<>'pending'or i->>'state'not in('approved','rejected')or c.person_id=actor then raise exception'Independent pending claim review required'using errcode='PT409';end if;
 if not boss_private.rails_actor_current(c.person_id)then raise exception'Verified active claimant required'using errcode='PT422';end if;
 if i->>'state'='approved'and(m.claim_state<>'unclaimed'or exists(select 1 from public.merchant_access_assignments a join public.roles r on r.id=a.role_id where a.merchant_id=m.id and r.key='merchant_owner'and a.status='active'))then raise exception'Merchant already claimed'using errcode='PT409';end if;
 update public.merchant_claims set state=i->>'state',review_reason=i->>'reason',reviewed_by=actor,reviewed_at=clock_timestamp()where id=c.id;
 if i->>'state'='approved'then
 insert into public.merchant_access_assignments(merchant_id,person_id,role_id,granted_by,ends_at)select m.id,c.person_id,id,actor,(i->>'ends_at')::timestamptz from public.roles where key='merchant_owner';
 update public.merchants set claim_state='reviewed',status='claimed',version=version+1,updated_at=clock_timestamp()where id=m.id;end if;id:=c.id;
 elsif action='merchant.review'then
 k:='merchant_reviews.manage';perform boss_private.merchant_require(actor,k,m.id);state:=i->>'state';
 if state not in('active','paused','suspended','archived','pending_review')or length(btrim(coalesce(i->>'reason','')))<10 then raise exception'Review reason required'using errcode='PT422';end if;
 update public.merchants set status=state,version=version+1,updated_at=clock_timestamp()where id=m.id;id:=m.id;
 elsif action='merchant.configure'then
 if not boss_private.merchant_platform(actor,'merchant_reviews.manage')then raise exception'Platform configuration required'using errcode='PT403';end if;k:='platform';
 update public.merchant_modules set status=i->>'status',starts_at=clock_timestamp(),ends_at=(i->>'ends_at')::timestamptz,
 configuration=jsonb_build_object('portal',coalesce((i->>'portal')::boolean,false),'offers',coalesce((i->>'offers')::boolean,false),'redemption',coalesce((i->>'redemption')::boolean,false))where merchant_id=m.id;id:=m.id;
 elsif action='merchant.edit'then
 k:='merchants.manage';perform boss_private.merchant_require(actor,k,m.id);
 if(i->>'expected_version')is null or m.version<>(i->>'expected_version')::bigint then raise exception'Stale merchant'using errcode='PT409';end if;
 update public.merchants set name=coalesce(i->>'name',name),description=coalesce(i->>'description',description),website=coalesce(i->>'website',website),public_phone=coalesce(i->>'public_phone',public_phone),version=version+1,updated_at=clock_timestamp()where id=m.id;id:=m.id;
 elsif action='staff.grant'then
 if not boss_private.merchant_platform(actor,'merchant_reviews.manage')or i->>'role'not in('support_reviewer','merchant_network_staff')then raise exception'Exact staff grant restricted'using errcode='PT403';end if;
 insert into public.merchant_staff_assignments(merchant_id,person_id,role_id,granted_by,ends_at)select m.id,(i->>'person_id')::uuid,id,actor,(i->>'ends_at')::timestamptz from public.roles where key=i->>'role'returning id into id;k:='platform';
 elsif action='staff.end'then
 if not boss_private.merchant_platform(actor,'merchant_reviews.manage')then raise exception'Exact staff grant restricted'using errcode='PT403';end if;
 update public.merchant_staff_assignments set status='ended'where id=(i->>'assignment_id')::uuid and merchant_id=m.id returning id into id;k:='platform';
 elsif action='access.grant'then
 k:='merchants.access_manage';perform boss_private.merchant_require(actor,k,m.id);
 if i->>'role'not in('merchant_admin','location_manager','offer_editor','redemption_clerk')or not boss_private.rails_actor_current((i->>'person_id')::uuid)then raise exception'Operational role and verified person required'using errcode='PT422';end if;
 if i->>'role'in('location_manager','redemption_clerk')and loc is null or i->>'role'='merchant_admin'and loc is not null then raise exception'Exact role scope required'using errcode='PT422';end if;
 insert into public.merchant_access_assignments(merchant_id,location_id,person_id,role_id,granted_by,ends_at)select m.id,loc,(i->>'person_id')::uuid,id,actor,(i->>'ends_at')::timestamptz from public.roles where key=i->>'role'returning id into id;
 elsif action='access.end'then
 k:='merchants.access_manage';perform boss_private.merchant_require(actor,k,m.id);
 select *into a from public.merchant_access_assignments where id=(i->>'assignment_id')::uuid and merchant_id=m.id for update;
 if a.id is null then raise exception'Assignment unavailable'using errcode='PT404';end if;
 if exists(select 1 from public.roles where id=a.role_id and key='merchant_owner')then raise exception'Ownership changes require reviewed support'using errcode='PT403';end if;
 update public.merchant_access_assignments set status='ended'where id=a.id;id:=a.id;
 elsif action='location.create'then
 k:='merchant_locations.manage';perform boss_private.merchant_require(actor,k,m.id);
 if not exists(select 1 from public.merchant_markets where id=(i->>'market_id')::uuid and status='active')then raise exception'Approved market required'using errcode='PT422';end if;
 insert into public.merchant_locations(merchant_id,market_id,name,address,city,postal_code,timezone,phone,website,hours_note)
 values(m.id,(i->>'market_id')::uuid,i->>'name',i->>'address',i->>'city',i->>'postal_code',i->>'timezone',i->>'phone',i->>'website',coalesce(i->>'hours_note',''))returning id into id;
 elsif action='location.edit'then
 k:='merchant_locations.manage';perform boss_private.merchant_require(actor,k,m.id,loc);
 select *into l from public.merchant_locations where id=loc and merchant_id=m.id for update;
 if l.id is null or(i->>'expected_version')is null or l.version<>(i->>'expected_version')::bigint then raise exception'Stale location'using errcode='PT409';end if;
 update public.merchant_locations set name=coalesce(i->>'name',name),hours_note=coalesce(i->>'hours_note',hours_note),status=coalesce(i->>'status',status),version=version+1 where id=l.id;id:=l.id;
 elsif action='family.create'then
 k:='merchant_offers.manage';perform boss_private.merchant_require(actor,k,m.id,loc);
 insert into public.merchant_offer_families(merchant_id,usage_limit,reset_period,usage_timezone,period_start,period_end,created_by)
 values(m.id,(i->>'usage_limit')::integer,i->>'reset_period',i->>'usage_timezone',(i->>'period_start')::timestamptz,(i->>'period_end')::timestamptz,actor)returning id into id;
 elsif action='family.status'then
 k:='merchant_offers.manage';perform boss_private.merchant_require(actor,k,m.id);
 update public.merchant_offer_families set status=i->>'status'where id=(i->>'family_id')::uuid and merchant_id=m.id returning id into id;
 elsif action='offer.create'then
 k:='merchant_offers.manage';select *into f from public.merchant_offer_families where id=(i->>'family_id')::uuid and merchant_id=m.id for update;
 if f.id is null then raise exception'Family unavailable'using errcode='PT404';end if;
 if i->>'location_policy'='all_current'then perform boss_private.merchant_require(actor,k,m.id);
 else if jsonb_typeof(i->'location_ids')is distinct from'array'or jsonb_array_length(i->'location_ids')not between 1 and 100 then raise exception'Exact bounded locations required'using errcode='PT422';end if;
 for loc in select value::text::uuid from jsonb_array_elements_text(i->'location_ids')loop perform boss_private.merchant_require(actor,k,m.id,loc);end loop;
 -- The receipt needs the exact grant if content is location scoped.
 if not boss_private.merchant_can(actor,k,m.id)and jsonb_array_length(i->'location_ids')<>1 then raise exception'One exact editor location required'using errcode='PT403';end if;
 end if;
 insert into public.merchant_offer_revisions(merchant_id,family_id,revision,title,description,offer_type,discount_bps,currency,amount_minor,buy_quantity,benefit_quantity,purchase_description,benefit_description,
 qualification,minimum_minor,qualifying_description,exclusions,stacking,stacking_policy,starts_at,ends_at,weekdays,local_start,local_end,weekly_special,location_policy,include_future,allow_local_pause,created_by)
 values(m.id,f.id,coalesce((select max(revision)+1 from public.merchant_offer_revisions where family_id=f.id),1),i->>'title',coalesce(i->>'description',''),i->>'offer_type',(i->>'discount_bps')::integer,
 i->>'currency',(i->>'amount_minor')::bigint,(i->>'buy_quantity')::integer,(i->>'benefit_quantity')::integer,i->>'purchase_description',i->>'benefit_description',i->>'qualification',(i->>'minimum_minor')::bigint,
 i->>'qualifying_description',coalesce(i->>'exclusions',''),i->>'stacking',i->>'stacking_policy',(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,
 coalesce((select array_agg(value::text::integer)from jsonb_array_elements_text(i->'weekdays')),array[0,1,2,3,4,5,6]),(i->>'local_start')::time,(i->>'local_end')::time,coalesce((i->>'weekly_special')::boolean,false),
 i->>'location_policy',coalesce((i->>'include_future')::boolean,false),coalesce((i->>'allow_local_pause')::boolean,true),actor)returning *into r;
 if r.location_policy='all_current'then insert into public.merchant_offer_locations(merchant_id,revision_id,location_id)select m.id,r.id,id from public.merchant_locations where merchant_id=m.id and status='active';
 else insert into public.merchant_offer_locations(merchant_id,revision_id,location_id)select m.id,r.id,value::text::uuid from jsonb_array_elements_text(i->'location_ids');end if;
 if not exists(select 1 from public.merchant_offer_locations where revision_id=r.id)then raise exception'One location required'using errcode='PT422';end if;
 insert into public.merchant_offer_events(revision_id,state,actor_id)values(r.id,'draft',actor);id:=r.id;
 if boss_private.merchant_can(actor,k,m.id)then loc:=null;end if;
 elsif action='offer.status'then
 select *into r from public.merchant_offer_revisions where id=(i->>'revision_id')::uuid and merchant_id=m.id;
 if r.id is null then raise exception'Offer unavailable'using errcode='PT404';end if;
 state:=i->>'state';oldstate:=boss_private.merchant_offer_state(r.id);
 if state in('published','scheduled','rejected','draft')then k:='merchant_reviews.manage';perform boss_private.merchant_require(actor,k,m.id);
 if oldstate<>'pending_review'or state in('published','scheduled')and length(btrim(coalesce(i->>'reason','')))<10 then raise exception'Pending independent review and reason required'using errcode='PT409';end if;
 -- All revisions retire before this approved replacement becomes current.
 if state in('published','scheduled')then insert into public.merchant_offer_events(revision_id,state,actor_id,reason)
 select q.id,'archived',actor,'Superseded by approved revision'from public.merchant_offer_revisions q where q.family_id=r.family_id and q.id<>r.id and boss_private.merchant_offer_state(q.id)in('published','scheduled','paused');end if;
 else k:='merchant_offers.manage';perform boss_private.merchant_require(actor,k,m.id,loc);
 if loc is not null and not exists(select 1 from public.merchant_offer_locations where revision_id=r.id and location_id=loc)then raise exception'Exact editor location required'using errcode='PT403';end if;
 if not boss_private.merchant_can(actor,k,m.id)and(r.include_future or(select count(*)from public.merchant_offer_locations where revision_id=r.id)<>1)then raise exception'Local editor cannot change corporate revision state'using errcode='PT403';end if;
 if state='pending_review'and oldstate not in('draft','rejected','paused')or state in('paused','archived')and oldstate not in('draft','pending_review','scheduled','published','paused','rejected')or state not in('pending_review','paused','archived')then raise exception'Offer transition unavailable'using errcode='PT409';end if;
 end if;
 insert into public.merchant_offer_events(revision_id,state,actor_id,reason)values(r.id,state,actor,coalesce(i->>'reason',''));id:=r.id;
 elsif action='offer.local'then
 k:='merchant_locations.manage';perform boss_private.merchant_require(actor,k,m.id,loc);
 select *into f from public.merchant_offer_families where id=(i->>'family_id')::uuid and merchant_id=m.id;
 if f.id is null or loc is null or not exists(select 1 from public.merchant_offer_revisions r where r.family_id=f.id and r.allow_local_pause and boss_private.merchant_offer_state(r.id)in('published','scheduled','paused')and(exists(select 1 from public.merchant_offer_locations t where t.revision_id=r.id and t.location_id=loc)or r.include_future))then raise exception'Local policy unavailable'using errcode='PT403';end if;
 insert into public.merchant_offer_local_state(merchant_id,family_id,location_id,paused,presentation_note)values(m.id,f.id,loc,(i->>'paused')::boolean,coalesce(i->>'presentation_note',''))
 on conflict(family_id,location_id)do update set paused=excluded.paused,presentation_note=excluded.presentation_note,version=public.merchant_offer_local_state.version+1;id:=f.id;
 else raise exception'Unsupported merchant action'using errcode='PT422';end if;
 if id is null then raise exception'Resource unavailable'using errcode='PT404';end if;
 perform boss_private.merchant_audit(actor,m.id,'merchant.'||action,id,request,jsonb_strip_nulls(jsonb_build_object('state',state,'location_id',loc)));
 return jsonb_build_object('merchant_id',m.id,'resource_id',id,'version',(select version from public.merchants where id=m.id),'_permission',k,'_location',loc);
end$$;
