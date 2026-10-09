create function boss_private.partner_require(actor uuid,permission text,provider uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$begin
 if permission not in('partners.view','partners.configure','partners.contract_approve','partners.catalog_review','partners.integration_activate','partners.revenue_report')or not boss_private.merchant_platform(actor,permission)or not exists(select 1 from public.modules where key='commerce'and status='active')then raise exception'Partner authority required'using errcode='PT403';end if;
 if provider is not null and not exists(select 1 from public.partner_providers where id=provider)then raise exception'Provider unavailable'using errcode='PT404';end if;
end$$;
create function boss_private.partner_lock(provider uuid)returns void language plpgsql volatile security definer set search_path=''as $$begin
 perform pg_advisory_xact_lock(hashtextextended('boss-partner:'||provider,0));
 perform 1 from public.partner_providers where id=provider for update;
end$$;
create function boss_private.partner_contract_active(contract uuid,at_time timestamptz default clock_timestamp())returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.partner_contract_revisions c where c.id=contract and c.starts_at<=at_time and c.ends_at>at_time
 and(select state from public.partner_contract_events where contract_id=c.id order by created_at desc,id desc limit 1)='approved')
$$;
create function boss_private.partner_audit(actor uuid,provider uuid,action text,resource uuid,request uuid)returns void language plpgsql volatile security definer set search_path=''as $$begin
 insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,request_id,after_data)
 values(actor,auth.uid(),'partner.'||action,'partner_provider',coalesce(resource,provider),'platform',request,jsonb_build_object('provider_id',provider));
end$$;
create function boss_private.partner_keys(input jsonb,allowed text[])returns void language plpgsql immutable set search_path=''as $$begin
 if jsonb_typeof(input)is distinct from'object'or octet_length(input::text)>1048576 or exists(select 1 from jsonb_object_keys(input)k where not k=any(allowed))then raise exception'Finite partner fields required'using errcode='PT422';end if;
end$$;
create function boss_private.partner_permission(action text)returns text language sql immutable set search_path=''as $$select case
 when action in('provider.create','provider.state','configuration.create')then'partners.configure'
 when action in('contract.create','contract.review','territory.create','territory.end','policy.create')then'partners.contract_approve'
 when action in('catalog.import','catalog.review','catalog.withdraw','catalog.pause','catalog.snapshot.begin','catalog.snapshot.complete','catalog.snapshot.abort')then'partners.catalog_review'
 when action='integration.activate'then'partners.integration_activate'
 when action in('transaction.create','transaction.event')then'partners.revenue_report'end$$;
create function boss_private.partner_import(actor uuid,provider uuid,i jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare cfg public.partner_config_revisions;item jsonb;s public.partner_benefit_sources;c public.partner_contract_revisions;run uuid;ids uuid[]:='{}';n integer:=0;ok integer:=0;bad integer:=0;withdrawn_count integer:=0;d text;prior public.partner_import_runs;seq bigint;rid uuid;ecode text;snapshot public.partner_catalog_snapshots;begin
 perform boss_private.partner_keys(i,array['provider_id','feed_sequence','kind','synthetic','items','snapshot_id']);
 if i->'synthetic' is distinct from'true'::jsonb or not exists(select 1 from public.partner_providers where id=provider and synthetic and state not in('suspended','terminated','archived'))or i->>'kind'not in('full','delta')or jsonb_typeof(i->'items')is distinct from'array'or jsonb_array_length(i->'items')>250 then raise exception'Bounded synthetic feed required'using errcode='PT422';end if;
 select *into cfg from public.partner_config_revisions where provider_id=provider order by revision desc limit 1;
 if cfg.id is null or cfg.starts_at>clock_timestamp()or cfg.ends_at<=clock_timestamp()or not'catalog_read'=any(cfg.capabilities)then raise exception'Configured catalog capability required'using errcode='PT409';end if;
 if i->>'snapshot_id'is not null then
 select *into snapshot from public.partner_catalog_snapshots where id=(i->>'snapshot_id')::uuid and provider_id=provider and status='open';
 if snapshot.id is null or i->>'kind'<>'full'then raise exception'Exact open snapshot required'using errcode='PT409';end if;
 elsif exists(select 1 from public.partner_catalog_snapshots where provider_id=provider and status='open')then raise exception'Finish or abort existing snapshot'using errcode='PT409';end if;
 seq:=(i->>'feed_sequence')::bigint;d:=encode(sha256(convert_to(i::text,'UTF8')),'hex');
 select *into prior from public.partner_import_runs where provider_id=provider and feed_sequence=seq;
 if prior.id is not null then if prior.digest<>d then raise exception'Feed identity conflict'using errcode='PT409';end if;
 return jsonb_build_object('resource_id',prior.id,'accepted',prior.accepted,'quarantined',prior.quarantined,'withdrawn',prior.withdrawn);end if;
 if seq<=coalesce((select max(feed_sequence)from public.partner_import_runs where provider_id=provider),0)then raise exception'Out of order feed'using errcode='PT409';end if;
 insert into public.partner_import_runs(provider_id,feed_sequence,kind,synthetic,digest,actor_id,request_id,snapshot_id)values(provider,seq,i->>'kind',true,d,actor,request,snapshot.id)returning id into run;
 for item in select value from jsonb_array_elements(i->'items')loop
 begin
 perform boss_private.partner_keys(item,array['external_id','source_revision','contract_id','category','title','public_description','member_terms','exclusions','country','region','market_id','product_id','minimum_tier','fulfillment','starts_at','ends_at','withdrawn']);
 if item->>'external_id' is null or item->>'external_id'!~'^[a-zA-Z0-9_.:-]{1,120}$'or coalesce((item->>'source_revision')::bigint,0)<=0 then raise exception'Invalid item'using errcode='PT422';end if;
 select *into s from public.partner_benefit_sources where provider_id=provider and external_id=item->>'external_id'for update;
 if s.id is null then insert into public.partner_benefit_sources(provider_id,external_id)values(provider,item->>'external_id')returning *into s;end if;
 if s.id=any(ids)then raise exception'Duplicate source in feed'using errcode='PT409';end if;
 d:=encode(sha256(convert_to(item::text,'UTF8')),'hex');
 if (item->>'source_revision')::bigint<s.current_revision then raise exception'Out of order item'using errcode='PT410';end if;
 if (item->>'source_revision')::bigint=s.current_revision then
 if d<>s.current_digest then raise exception'Revision conflict'using errcode='PT409';end if;
 update public.partner_benefit_sources set last_verified_at=clock_timestamp()where id=s.id;
 else
 if item->'withdrawn'='true'::jsonb then update public.partner_benefit_sources set current_revision=(item->>'source_revision')::bigint,current_digest=d,status='withdrawn',last_verified_at=clock_timestamp()where id=s.id;withdrawn_count:=withdrawn_count+1;
 else
 select *into c from public.partner_contract_revisions where id=(item->>'contract_id')::uuid and provider_id=provider;
 if c.id is null or c.product_id<>(item->>'product_id')::uuid or not item->>'country'=any(c.countries)or not item->>'category'=any(c.categories)then raise exception'Contract resource mismatch'using errcode='PT422';end if;
 insert into public.partner_benefit_revisions(provider_id,source_id,source_revision,contract_id,category,title,public_description,member_terms,exclusions,country,region,market_id,product_id,minimum_tier,fulfillment,starts_at,ends_at,source_digest)
 values(provider,s.id,(item->>'source_revision')::bigint,c.id,item->>'category',item->>'title',coalesce(item->>'public_description',''),item->>'member_terms',coalesce(item->>'exclusions',''),item->>'country',coalesce(item->>'region',''),(item->>'market_id')::uuid,c.product_id,item->>'minimum_tier',item->>'fulfillment',(item->>'starts_at')::timestamptz,(item->>'ends_at')::timestamptz,d)returning id into rid;
 update public.partner_benefit_sources set current_revision=(item->>'source_revision')::bigint,current_digest=d,status='available',last_verified_at=clock_timestamp()where id=s.id;
 end if;end if;
 ids:=array_append(ids,s.id);ok:=ok+1;
 exception when check_violation or not_null_violation or foreign_key_violation or invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or invalid_datetime_format or invalid_parameter_value or sqlstate'PT422'or sqlstate'PT409'or sqlstate'PT410'then
 ecode:=case sqlstate when'PT409'then'revision_conflict'when'PT410'then'out_of_order'else'invalid_item'end;
 insert into public.partner_import_quarantine(run_id,item_index,external_id,category)values(run,n,case when item->>'external_id'~'^[a-zA-Z0-9_.:-]{1,120}$'then item->>'external_id'end,ecode);bad:=bad+1;
 end;n:=n+1;end loop;
 -- An incomplete/invalid full feed cannot mass-withdraw valid records.
 if i->>'kind'='full'and cfg.full_withdraw_missing and bad=0 and snapshot.id is null then
 update public.partner_benefit_sources set status='withdrawn'where provider_id=provider and status='available'and not id=any(ids);get diagnostics n=row_count;withdrawn_count:=withdrawn_count+n;end if;
 if snapshot.id is not null then insert into public.partner_snapshot_items(snapshot_id,source_id,run_id)select snapshot.id,v,run from unnest(ids)v on conflict(snapshot_id,source_id)do nothing;end if;
 update public.partner_import_runs set accepted=ok,quarantined=bad,withdrawn=withdrawn_count where id=run;
 return jsonb_build_object('resource_id',run,'accepted',ok,'quarantined',bad,'withdrawn',withdrawn_count);
end$$;
create function boss_private.partner_operate(actor uuid,action text,i jsonb,request uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare provider uuid:=(i->>'provider_id')::uuid;p public.partner_providers;id uuid;c public.partner_contract_revisions;cfg public.partner_config_revisions;r public.partner_benefit_revisions;pol public.partner_commission_policies;tx public.partner_transaction_sources;ev public.partner_transaction_events;oldstate text;nextstate text;begin
 if action='provider.create'then
 perform boss_private.partner_keys(i,array['key','name','legal_reference','support_reference','synthetic']);
 insert into public.partner_providers(key,name,legal_reference,support_reference,synthetic,created_by)values(i->>'key',i->>'name',i->>'legal_reference',i->>'support_reference',coalesce((i->>'synthetic')::boolean,false),actor)returning id into id;
 return jsonb_build_object('resource_id',id,'provider_id',id,'version',1);
 end if;
 select *into p from public.partner_providers where id=provider for update;
 if p.id is null then raise exception'Provider unavailable'using errcode='PT404';end if;
 if p.state in('terminated','archived')and action not in('provider.state','territory.end','catalog.withdraw','catalog.pause','catalog.snapshot.abort','transaction.event')then raise exception'Provider closed'using errcode='PT409';end if;
 if action='integration.activate'then raise exception'Phase 8B1 external activation locked'using errcode='PT403';end if;
 if action='provider.state'then
 perform boss_private.partner_keys(i,array['provider_id','expected_version','state','reason']);
 nextstate:=i->>'state';
 if p.version is distinct from(i->>'expected_version')::bigint then raise exception'Stale provider'using errcode='PT409';end if;
 if not(p.state='prospect'and nextstate='evaluation'or p.state='evaluation'and nextstate='contract_pending'or p.state='contract_pending'and nextstate='approved'or p.state='approved'and nextstate='configured'or p.state in('approved','configured')and nextstate='suspended'or p.state='suspended'and nextstate='approved'or p.state not in('terminated','archived')and nextstate='terminated'or p.state<>'archived'and nextstate='archived')then raise exception'Invalid provider transition'using errcode='PT409';end if;
 if nextstate in('approved','configured')and not exists(select 1 from public.partner_contract_revisions where provider_id=provider and boss_private.partner_contract_active(id))then raise exception'Effective approved contract required'using errcode='PT409';end if;
 if nextstate='configured'and not exists(select 1 from public.partner_config_revisions where provider_id=provider and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp()))then raise exception'Configuration required'using errcode='PT409';end if;
 update public.partner_providers set state=nextstate,version=version+1 where id=provider returning version into p.version;
 insert into public.partner_provider_events(provider_id,state,actor_id,reason,request_id)values(provider,nextstate,actor,i->>'reason',request);id:=provider;
 elsif action='configuration.create'then
 perform boss_private.partner_keys(i,array['provider_id','method','capabilities','credential_reference','full_withdraw_missing','max_stale_seconds','starts_at','ends_at']);
 if p.state in('terminated','archived')then raise exception'Provider closed'using errcode='PT409';end if;
 insert into public.partner_config_revisions(provider_id,revision,module_id,method,capabilities,credential_reference,full_withdraw_missing,max_stale_seconds,starts_at,ends_at,created_by)
 select provider,coalesce((select max(revision)+1 from public.partner_config_revisions where provider_id=provider),1),m.id,i->>'method',array(select jsonb_array_elements_text(i->'capabilities')),i->>'credential_reference',coalesce((i->>'full_withdraw_missing')::boolean,false),(i->>'max_stale_seconds')::integer,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor from public.modules m where key='commerce'returning id into id;
 elsif action='contract.create'then
 perform boss_private.partner_keys(i,array['provider_id','document_reference','rights_holder_reference','countries','categories','methods','product_id','minimum_tier','display_rights','caching_rights','branding_rules','attribution_rules','sharing_fields','retention_days','refund_policy_reference','starts_at','ends_at']);
 if p.state in('terminated','archived')then raise exception'Provider closed'using errcode='PT409';end if;
 insert into public.partner_contract_revisions(provider_id,revision,document_reference,rights_holder_reference,countries,categories,methods,product_id,minimum_tier,display_rights,caching_rights,branding_rules,attribution_rules,sharing_fields,retention_days,refund_policy_reference,starts_at,ends_at,created_by)
 values(provider,coalesce((select max(revision)+1 from public.partner_contract_revisions where provider_id=provider),1),i->>'document_reference',i->>'rights_holder_reference',array(select jsonb_array_elements_text(i->'countries')),array(select jsonb_array_elements_text(i->'categories')),array(select jsonb_array_elements_text(i->'methods')),(i->>'product_id')::uuid,i->>'minimum_tier',(i->>'display_rights')::boolean,(i->>'caching_rights')::boolean,i->>'branding_rules',i->>'attribution_rules',array(select jsonb_array_elements_text(i->'sharing_fields')),(i->>'retention_days')::integer,i->>'refund_policy_reference',(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning id into id;
 elsif action='contract.review'then
 perform boss_private.partner_keys(i,array['provider_id','contract_id','state','approval_reference']);
 select *into c from public.partner_contract_revisions where id=(i->>'contract_id')::uuid and provider_id=provider;
 if c.id is null then raise exception'Contract unavailable'using errcode='PT404';end if;
 if i->>'state'='approved'and(c.created_by=actor or c.ends_at<=clock_timestamp()or p.state in('terminated','archived'))then raise exception'Independent effective contract review required'using errcode='PT409';end if;
 insert into public.partner_contract_events(provider_id,contract_id,state,actor_id,approval_reference,request_id)values(provider,c.id,i->>'state',actor,i->>'approval_reference',request)returning id into id;
 elsif action='territory.create'then
 perform boss_private.partner_keys(i,array['provider_id','contract_id','country','region','market_id','starts_at','ends_at']);
 select *into c from public.partner_contract_revisions where id=(i->>'contract_id')::uuid and provider_id=provider;
 if c.id is null or not i->>'country'=any(c.countries)or not boss_private.partner_contract_active(c.id)then raise exception'Approved contract territory required'using errcode='PT409';end if;
 if i->>'market_id'is not null and not exists(select 1 from public.merchant_markets where id=(i->>'market_id')::uuid and country=i->>'country'and region=i->>'region'and status='active')then raise exception'Exact territory anchor required'using errcode='PT422';end if;
 insert into public.partner_territories(provider_id,contract_id,country,region,market_id,starts_at,ends_at,created_by)values(provider,c.id,i->>'country',coalesce(i->>'region',''),(i->>'market_id')::uuid,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning id into id;
 elsif action='territory.end'then
 perform boss_private.partner_keys(i,array['provider_id','territory_id']);update public.partner_territories set status='ended'where id=(i->>'territory_id')::uuid and provider_id=provider returning id into id;
 elsif action='catalog.snapshot.begin'then
 perform boss_private.partner_keys(i,array['provider_id','expected_items']);
 if not p.synthetic or p.state in('suspended','terminated','archived')then raise exception'Synthetic active snapshot required'using errcode='PT409';end if;
 insert into public.partner_catalog_snapshots(provider_id,expected_items,created_by)values(provider,(i->>'expected_items')::bigint,actor)returning id into id;
 elsif action in('catalog.snapshot.complete','catalog.snapshot.abort')then
 perform boss_private.partner_keys(i,array['provider_id','snapshot_id']);
 if not exists(select 1 from public.partner_catalog_snapshots where id=(i->>'snapshot_id')::uuid and provider_id=provider and status='open')then raise exception'Exact open snapshot required'using errcode='PT409';end if;
 if action='catalog.snapshot.complete'then
 if(select count(*)from public.partner_snapshot_items where snapshot_id=(i->>'snapshot_id')::uuid)is distinct from(select expected_items from public.partner_catalog_snapshots where id=(i->>'snapshot_id')::uuid)
 or exists(select 1 from public.partner_import_quarantine q join public.partner_import_runs pr on pr.id=q.run_id where pr.snapshot_id=(i->>'snapshot_id')::uuid)then raise exception'Complete valid snapshot required'using errcode='PT409';end if;
 select *into cfg from public.partner_config_revisions where provider_id=provider order by revision desc limit 1;
 if cfg.full_withdraw_missing then update public.partner_benefit_sources set status='withdrawn'where provider_id=provider and not exists(select 1 from public.partner_snapshot_items si where si.source_id=partner_benefit_sources.id and si.snapshot_id=(i->>'snapshot_id')::uuid);end if;
 end if;
 update public.partner_catalog_snapshots set status=case action when'catalog.snapshot.complete'then'complete'else'aborted'end where id=(i->>'snapshot_id')::uuid returning id into id;
 elsif action='catalog.import'then return boss_private.partner_import(actor,provider,i,request)||jsonb_build_object('provider_id',provider);
 elsif action='catalog.review'then
 perform boss_private.partner_keys(i,array['provider_id','revision_id','state']);
 select *into r from public.partner_benefit_revisions where id=(i->>'revision_id')::uuid and provider_id=provider;
 if r.id is null then raise exception'Catalog revision unavailable'using errcode='PT404';end if;
 if i->>'state'='reviewed'and(not boss_private.partner_contract_active(r.contract_id)or not exists(select 1 from public.partner_benefit_sources where id=r.source_id and current_revision=r.source_revision and status='available')or p.state not in('approved','configured')or r.ends_at<=clock_timestamp())then raise exception'Current licensed catalog required'using errcode='PT409';end if;
 insert into public.partner_benefit_reviews(provider_id,revision_id,state,actor_id,request_id)values(provider,r.id,i->>'state',actor,request)returning id into id;
 elsif action in('catalog.withdraw','catalog.pause')then
 perform boss_private.partner_keys(i,array['provider_id','source_id']);update public.partner_benefit_sources set status=case action when'catalog.withdraw'then'withdrawn'else'paused'end where id=(i->>'source_id')::uuid and provider_id=provider returning id into id;
 elsif action='policy.create'then
 perform boss_private.partner_keys(i,array['provider_id','contract_id','currency','basis','fixed_minor','rate_ppm','recognition_condition','starts_at','ends_at']);
 if not exists(select 1 from public.partner_contract_revisions where id=(i->>'contract_id')::uuid and provider_id=provider)then raise exception'Contract unavailable'using errcode='PT404';end if;
 insert into public.partner_commission_policies(provider_id,contract_id,revision,currency,basis,fixed_minor,rate_ppm,recognition_condition,starts_at,ends_at,created_by)
 values(provider,(i->>'contract_id')::uuid,coalesce((select max(revision)+1 from public.partner_commission_policies where contract_id=(i->>'contract_id')::uuid),1),i->>'currency',i->>'basis',(i->>'fixed_minor')::bigint,(i->>'rate_ppm')::integer,i->>'recognition_condition',(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,actor)returning id into id;
 elsif action='transaction.create'then
 perform boss_private.partner_keys(i,array['provider_id','external_id','revision_id','policy_id','currency','eligible_minor','attributed_person_id','native_sales_lead_id','synthetic','occurred_at','evidence_reference']);
 select *into pol from public.partner_commission_policies where id=(i->>'policy_id')::uuid and provider_id=provider;
 select *into r from public.partner_benefit_revisions where id=(i->>'revision_id')::uuid and provider_id=provider;
 if i->'synthetic'is distinct from'true'::jsonb or not p.synthetic or pol.id is null or r.id is null or r.contract_id<>pol.contract_id or pol.currency is distinct from i->>'currency'or not boss_private.partner_contract_active(pol.contract_id,(i->>'occurred_at')::timestamptz)or pol.starts_at>(i->>'occurred_at')::timestamptz or pol.ends_at<=(i->>'occurred_at')::timestamptz then raise exception'Exact synthetic commercial evidence required'using errcode='PT422';end if;
 -- Native acquisition attribution is an optional reference, never rep commission authority.
 insert into public.partner_transaction_sources(provider_id,external_id,benefit_revision_id,policy_id,currency,eligible_minor,attributed_person_id,native_sales_lead_id,synthetic,occurred_at,evidence_reference,created_by)
 values(provider,i->>'external_id',r.id,pol.id,i->>'currency',(i->>'eligible_minor')::bigint,(i->>'attributed_person_id')::uuid,(i->>'native_sales_lead_id')::uuid,true,(i->>'occurred_at')::timestamptz,i->>'evidence_reference',actor)returning id into id;
 elsif action='transaction.event'then
 perform boss_private.partner_keys(i,array['provider_id','transaction_id','external_event_id','kind','adjustment_minor','corrects_event_id','evidence_reference']);
 select *into tx from public.partner_transaction_sources where id=(i->>'transaction_id')::uuid and provider_id=provider;
 if tx.id is null then raise exception'Transaction unavailable'using errcode='PT404';end if;
 nextstate:=i->>'kind';select kind into oldstate from public.partner_transaction_events where transaction_id=tx.id and kind in('requested','confirmed','fulfilled','settled','canceled')order by created_at desc,id desc limit 1;
 if nextstate='confirmed'and coalesce(oldstate,'')<>'requested'or nextstate='fulfilled'and coalesce(oldstate,'')<>'confirmed'or nextstate='settled'and coalesce(oldstate,'')<>'fulfilled'or nextstate='requested'and oldstate is not null then raise exception'Invalid transaction lifecycle'using errcode='PT409';end if;
 if nextstate='correction'then
 select *into ev from public.partner_transaction_events where id=(i->>'corrects_event_id')::uuid and transaction_id=tx.id and provider_id=provider and kind='refund';
 if ev.id is null or exists(select 1 from public.partner_transaction_events where corrects_event_id=ev.id)then raise exception'Exact uncorrected refund required'using errcode='PT409';end if;
 end if;
 if nextstate='refund'and(coalesce((i->>'adjustment_minor')::bigint,0)<=0 or coalesce((i->>'adjustment_minor')::bigint,0)+(select coalesce(sum(adjustment_minor),0)from public.partner_transaction_events e where transaction_id=tx.id and kind='refund'and not exists(select 1 from public.partner_transaction_events x where x.corrects_event_id=e.id))>tx.eligible_minor)then raise exception'Bounded refund evidence required'using errcode='PT422';end if;
 if nextstate<>'refund'and coalesce((i->>'adjustment_minor')::bigint,0)<>0 then raise exception'Only refund adjusts eligible basis'using errcode='PT422';end if;
 insert into public.partner_transaction_events(provider_id,transaction_id,external_event_id,kind,adjustment_minor,corrects_event_id,evidence_reference,actor_id,request_id)
 values(provider,tx.id,i->>'external_event_id',nextstate,coalesce((i->>'adjustment_minor')::bigint,0),(i->>'corrects_event_id')::uuid,i->>'evidence_reference',actor,request)returning id into id;
 else raise exception'Unsupported partner command'using errcode='PT422';end if;
 if id is null then raise exception'Exact resource unavailable'using errcode='PT404';end if;
 return jsonb_build_object('resource_id',id,'provider_id',provider,'version',p.version);
end$$;
create function boss_private.partner_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare actor uuid;request uuid;action text;i jsonb;provider uuid;k text;d text;r boss_private.partner_receipts;result jsonb;begin
 perform boss_private.require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.partner_keys(command,array['request_id','action','input']);request:=(command->>'request_id')::uuid;action:=command->>'action';i:=command->'input';
 k:=boss_private.partner_permission(action);if request is null or k is null then raise exception'Finite command required'using errcode='PT422';end if;
 perform boss_private.discount_fence(actor);perform boss_private.partner_require(actor,k);
 provider:=(i->>'provider_id')::uuid;
 perform pg_advisory_xact_lock(hashtextextended('boss-partner-request:'||actor||':'||request,0));
 if provider is not null then perform boss_private.partner_lock(provider);perform boss_private.partner_require(actor,k,provider);end if;
 d:=encode(sha256(convert_to(command::text,'UTF8')),'hex');select *into r from boss_private.partner_receipts where actor_id=actor and request_id=request;
 if r.request_id is not null then if r.digest<>d then raise exception'Request identity conflict'using errcode='PT409';end if;return r.result;end if;
 result:=boss_private.partner_operate(actor,action,i,request);provider:=coalesce(provider,(result->>'provider_id')::uuid);
 perform boss_private.partner_audit(actor,provider,action,(result->>'resource_id')::uuid,request);
 insert into boss_private.partner_receipts(actor_id,request_id,action,provider_id,digest,result)values(actor,request,action,provider,d,result);
 return result;
exception when unique_violation then raise exception'Partner identity conflict'using errcode='PT409';
 when check_violation or not_null_violation or foreign_key_violation or invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or invalid_datetime_format or invalid_parameter_value then raise exception'Invalid partner contract'using errcode='PT422';
end$$;

-- Fail closed at this migration boundary, including projects with broad defaults.
do $$declare t record;f record;begin
 for t in select schemaname,tablename from pg_tables where schemaname in('public','boss_private')and tablename like'partner_%'loop
 execute format('alter table %I.%I enable row level security',t.schemaname,t.tablename);
 execute format('revoke all on %I.%I from public,anon,authenticated,service_role,boss_payment_worker',t.schemaname,t.tablename);end loop;
 for f in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'partner_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',f.signature);end loop;
end$$;
