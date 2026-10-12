create table boss_private.bucks_requests(
 request_id uuid primary key,actor_id uuid not null references public.people(id),command jsonb not null,result jsonb not null,created_at timestamptz not null default clock_timestamp());
alter table boss_private.bucks_requests enable row level security;
create index bucks_requests_actor_idx on boss_private.bucks_requests(actor_id);
revoke all on boss_private.bucks_requests from public,anon,authenticated,service_role;
create function boss_private.bucks_identity_lock()returns trigger language plpgsql set search_path=''as $$begin
 if tg_table_name='boss_bucks_wallets'and(new.id<>old.id or new.household_id<>old.household_id or new.currency<>old.currency or new.created_at<>old.created_at)then raise exception'Wallet identity is immutable'using errcode='23514';end if;
 if tg_table_name='boss_bucks_access'and(new.wallet_id<>old.wallet_id or new.person_id<>old.person_id or new.guardian_relationship_id<>old.guardian_relationship_id or new.organization_id<>old.organization_id or new.access_kind<>old.access_kind)then raise exception'Wallet access context is immutable'using errcode='23514';end if;return new;
end$$;
create trigger boss_bucks_wallet_identity before update on public.boss_bucks_wallets for each row execute function boss_private.bucks_identity_lock();
create trigger boss_bucks_access_identity before update on public.boss_bucks_access for each row execute function boss_private.bucks_identity_lock();
create trigger boss_bucks_wallet_no_delete before delete on public.boss_bucks_wallets for each row execute function boss_private.reject_audit_rewrite();
create trigger boss_bucks_access_no_delete before delete on public.boss_bucks_access for each row execute function boss_private.reject_audit_rewrite();
create trigger boss_bucks_wallet_no_truncate before truncate on public.boss_bucks_wallets execute function boss_private.reject_audit_rewrite();
create trigger boss_bucks_access_no_truncate before truncate on public.boss_bucks_access execute function boss_private.reject_audit_rewrite();
create function boss_private.bucks_access_audit()returns trigger language plpgsql volatile security definer set search_path=''as $$begin
 perform boss_private.bucks_audit(boss_private.current_person_id(),'boss_bucks.access.change',new.organization_id,new.wallet_id,null,null,jsonb_build_object('access_id',new.id,'access_kind',new.access_kind,'status',new.status,'starts_at',new.starts_at,'ends_at',new.ends_at));return new;
end$$;
create trigger boss_bucks_access_history after insert or update on public.boss_bucks_access for each row execute function boss_private.bucks_access_audit();
create function boss_private.bucks_module_configuration()returns trigger language plpgsql set search_path=''as $$begin
 if exists(select 1 from public.modules where id=new.module_id and key='boss_bucks')and(jsonb_typeof(new.configuration)<>'object'or exists(
 select 1 from jsonb_each(new.configuration)e where key<>all(array['wallet','fundraising_issuance','family_wallet','organization_wallet_reporting','charge_eligibility_preview'])or jsonb_typeof(value)<>'boolean'))then
 raise exception'Invalid Boss Bucks feature configuration'using errcode='PT422';end if;return new;
end$$;
create trigger boss_bucks_module_features before insert or update on public.organization_modules for each row execute function boss_private.bucks_module_configuration();

create function boss_private.bucks_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;action text;i jsonb;request uuid;org uuid;household uuid;subject uuid;wallet uuid;campaign uuid;fundraiser uuid;guardian public.guardian_relationships;
 c public.fundraising_campaigns;f public.fundraising_fundraisers;result jsonb;prior boss_private.bucks_requests;policy uuid;revision bigint;mode text;bps integer;channels text[];begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();action:=command->>'action';i:=command->'input';request:=(command->>'request_id')::uuid;
 if actor is null or request is null or jsonb_typeof(command)<>'object'or jsonb_typeof(i)<>'object'or exists(select 1 from jsonb_object_keys(command)k where k<>all(array['action','input','request_id']))then raise exception'Invalid wallet command'using errcode='PT422';end if;
 if action='features.configure'then
 if exists(select 1 from jsonb_object_keys(i)k where k<>all(array['organization_id','features']))or jsonb_typeof(i->'features')is distinct from'object'or exists(select 1 from jsonb_each(i->'features')e where key<>all(array['wallet','fundraising_issuance','family_wallet','organization_wallet_reporting','charge_eligibility_preview'])or jsonb_typeof(value)<>'boolean')then raise exception'Invalid feature fields'using errcode='PT422';end if;
 org:=(i->>'organization_id')::uuid;
 perform 1 from public.organizations where id=org for update;
 perform 1 from public.organization_modules where organization_id=org and module_id in(select id from public.modules where key='boss_bucks')order by id for update;
 perform boss_private.bucks_fence(actor,org);
 if not boss_private.bucks_role(actor,'boss_bucks.policy_manage',org)or not boss_private.has_permission('organization.manage',org)or not exists(select 1 from public.organization_modules m join public.modules k on k.id=m.module_id and k.key='boss_bucks'and k.status='active'where m.organization_id=org and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))then raise exception'Access denied'using errcode='PT403';end if;
 elsif action='wallet.provision'then
 if exists(select 1 from jsonb_object_keys(i)k where k<>all(array['organization_id','household_id','dependent_person_id','currency']))then raise exception'Invalid provision fields'using errcode='PT422';end if;
 org:=(i->>'organization_id')::uuid;household:=(i->>'household_id')::uuid;subject:=(i->>'dependent_person_id')::uuid;
 perform boss_private.bucks_fence(actor,org,null,household);
 perform 1 from public.organization_memberships where person_id=subject and organization_id=org order by id for share;
 if not exists(select 1 from public.organization_memberships where person_id=subject and organization_id=org and status='active'and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp()))or not boss_private.bucks_feature(org,'family_wallet')or not boss_private.bucks_guardian(actor,subject,household)or i->>'currency'!~'^[A-Z]{3}$'or i->>'currency' is null then raise exception'Access denied'using errcode='PT403';end if;
 select *into guardian from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=subject and can_manage_boss_bucks and authority_status='active'
 and verified_at<=clock_timestamp()and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp())order by id limit 1;
 elsif action='policy.create'then
 if exists(select 1 from jsonb_object_keys(i)k where k<>all(array['campaign_id','mode','basis_points','currency','channels','availability_seconds','expiry_seconds']))then raise exception'Invalid policy fields'using errcode='PT422';end if;
 campaign:=(i->>'campaign_id')::uuid;select *into c from public.fundraising_campaigns where id=campaign for update;org:=c.organization_id;
 perform boss_private.bucks_fence(actor,org);
 if c.id is null or not boss_private.bucks_feature(org,'fundraising_issuance')or not boss_private.fundraising_module(org,'fundraising')or not boss_private.bucks_role(actor,'boss_bucks.policy_manage',org)then raise exception'Access denied'using errcode='PT403';end if;
 mode:=i->>'mode';bps:=(i->>'basis_points')::integer;select array_agg(value)into channels from jsonb_array_elements_text(i->'channels');
 if mode not in('none','percentage')or mode is null or bps is null or bps not between 0 and 10000 or mode='none'and bps<>0 or i->>'currency' is distinct from c.currency
 or channels is null or cardinality(channels)=0 or not(channels<@array['direct_support','money_board']::text[])then raise exception'Invalid earning policy'using errcode='PT422';end if;
 elsif action='fundraiser.bind_household'then
 if exists(select 1 from jsonb_object_keys(i)k where k<>all(array['fundraiser_id','household_id']))then raise exception'Invalid binding fields'using errcode='PT422';end if;
 fundraiser:=(i->>'fundraiser_id')::uuid;household:=(i->>'household_id')::uuid;select campaign_id into campaign from public.fundraising_fundraisers where id=fundraiser;
 select *into c from public.fundraising_campaigns where id=campaign for update;select *into f from public.fundraising_fundraisers where id=fundraiser for update;org:=c.organization_id;
 perform boss_private.bucks_fence(actor,org,null,household);
 if f.id is null or not boss_private.bucks_feature(org,'family_wallet')or not boss_private.fundraising_related(actor,f)or not boss_private.bucks_guardian(actor,f.person_id,household)then raise exception'Access denied'using errcode='PT403';end if;
 select *into guardian from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=f.person_id and can_manage_boss_bucks and authority_status='active'and verified_at<=clock_timestamp()and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp())order by id limit 1;
 if f.household_id is not null and f.household_id<>household or exists(select 1 from public.boss_bucks_fundraiser_bindings where fundraiser_id=f.id and household_id<>household)then raise exception'Household already bound'using errcode='PT409';end if;
 elsif action='access.end'then
 if exists(select 1 from jsonb_object_keys(i)k where k<>all(array['wallet_id']))then raise exception'Invalid access fields'using errcode='PT422';end if;
 wallet:=(i->>'wallet_id')::uuid;perform boss_private.bucks_fence(actor,null,wallet);
 if not boss_private.bucks_accessible(actor,wallet,true)then raise exception'Access denied'using errcode='PT403';end if;
 else raise exception'Unsupported wallet action'using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-bucks-request:'||request::text,0));
 select *into prior from boss_private.bucks_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command<>command then raise exception'Request conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true}'::jsonb;end if;
 if action='features.configure'then
 update public.organization_modules set configuration=i->'features'where id=(select m.id from public.organization_modules m join public.modules k on k.id=m.module_id and k.key='boss_bucks'where m.organization_id=org and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())order by m.starts_at desc,m.id limit 1);
 result:=jsonb_build_object('action',action,'replayed',false);perform boss_private.bucks_audit(actor,'boss_bucks.features.configure',org,null,null,request,i->'features');
 elsif action='wallet.provision'then
 insert into public.boss_bucks_wallets(household_id,currency)values(household,i->>'currency')on conflict(household_id,currency)do nothing;
 select id into wallet from public.boss_bucks_wallets where household_id=household and currency=i->>'currency'and status='active'for update;
 if wallet is null then raise exception'Wallet retired'using errcode='PT409';end if;
 insert into public.boss_bucks_access(wallet_id,person_id,guardian_relationship_id,organization_id,access_kind,ends_at)values(wallet,actor,guardian.id,org,'manager',guardian.ends_at)
 on conflict(wallet_id,person_id,guardian_relationship_id)do nothing;
 if not boss_private.bucks_accessible(actor,wallet,true)then raise exception'Wallet access ended'using errcode='PT403';end if;
 result:=jsonb_build_object('action',action,'wallet_id',wallet,'replayed',false);perform boss_private.bucks_audit(actor,'boss_bucks.wallet.provision',org,wallet,null,request);
 elsif action='policy.create'then
 select coalesce(max(boss_bucks_policy_revisions.revision),0)+1 into revision from public.boss_bucks_policy_revisions where campaign_id=campaign;
 insert into public.boss_bucks_policy_revisions(campaign_id,organization_id,revision,mode,basis_points,currency,channels,availability_seconds,expiry_seconds,created_by,request_id)
 values(campaign,org,revision,mode,bps,c.currency,channels,coalesce((i->>'availability_seconds')::integer,0),(i->>'expiry_seconds')::integer,actor,request)returning id into policy;
 result:=jsonb_build_object('action',action,'policy_id',policy,'revision',revision,'replayed',false);perform boss_private.bucks_audit(actor,'boss_bucks.policy.create',org,null,null,request,jsonb_build_object('policy_id',policy,'campaign_id',campaign,'revision',revision));
 elsif action='fundraiser.bind_household'then
 insert into public.boss_bucks_fundraiser_bindings(fundraiser_id,household_id,authorized_by,guardian_relationship_id)values(f.id,household,actor,guardian.id)on conflict(fundraiser_id)do nothing;
 update public.fundraising_fundraisers set household_id=household,version=version+1 where id=f.id and household_id is distinct from household;
 result:=jsonb_build_object('action',action,'fundraiser_id',f.id,'replayed',false);perform boss_private.bucks_audit(actor,'boss_bucks.household.bind',org,null,null,request,jsonb_build_object('fundraiser_id',f.id,'household_id',household));
 else
 update public.boss_bucks_access set status='ended',ends_at=greatest(clock_timestamp(),starts_at+interval'1 microsecond')where wallet_id=wallet and person_id=actor and status='active';
 result:=jsonb_build_object('action',action,'wallet_id',wallet,'replayed',false);perform boss_private.bucks_audit(actor,'boss_bucks.access.end',null,wallet,null,request);
 end if;
 insert into boss_private.bucks_requests(request_id,actor_id,command,result)values(request,actor,command,result);return result;
exception when invalid_text_representation or numeric_value_out_of_range or check_violation then raise exception'Invalid wallet fields'using errcode='PT422';end$$;
create function public.boss_bucks_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.bucks_mutate(command)$$;
revoke all on function public.boss_bucks_mutate(jsonb),boss_private.bucks_mutate(jsonb),boss_private.bucks_identity_lock()from public,anon,authenticated,service_role;
grant execute on function public.boss_bucks_mutate(jsonb),boss_private.bucks_mutate(jsonb)to authenticated;
