create function boss_private.discount_feature(org uuid,feature text)returns boolean language sql volatile security definer set search_path=''as $$
 select feature in('discount_membership','membership_trials','physical_cards','membership_sales','membership_upgrades')and exists(
 select 1 from public.organization_modules m join public.modules k on k.id=m.module_id and k.key='boss_bucks'and k.status='active'
 join public.organizations o on o.id=m.organization_id and o.status='active'where m.organization_id=org and m.status='active'
 and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())and m.configuration->feature='true'::jsonb)
$$;
create function boss_private.discount_platform(actor uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.rails_actor_current(actor)and exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.key='boss_bucks.product_manage'and p.status='active'
 where a.person_id=actor and a.scope_type='platform'and a.scope_id is null and a.organization_id is null and r.key in('platform_administrator','super_administrator')
 and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()))
$$;
create function boss_private.discount_role(actor uuid,permission text,org uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select permission in('boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage')and boss_private.rails_actor_current(actor)
 and exists(select 1 from public.organizations where id=org and status='active')and exists(
 select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'join public.role_permissions rp on rp.role_id=r.id
 join public.permissions p on p.id=rp.permission_id and p.key=permission and p.status='active'where a.person_id=actor and a.status='active'
 and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and(
 a.scope_type='platform'and a.organization_id is null and a.scope_id is null and r.key in('platform_administrator','super_administrator')
 or a.organization_id=org and a.scope_type='organization'and a.scope_id=org and exists(select 1 from public.organization_memberships m
 where m.person_id=actor and m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))))
$$;
create function boss_private.discount_subject(actor uuid,subject_type text,subject uuid,manage boolean default false)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.rails_actor_current(actor)and case subject_type
 when'person'then actor=subject and exists(select 1 from public.people where id=subject and status='active')
 when'household'then exists(select 1 from public.household_memberships m join public.households h on h.id=m.household_id and h.status='active'
 where m.household_id=subject and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())
 and(not manage or m.is_primary_contact))else false end
$$;
create function boss_private.discount_fence(actor uuid,org uuid default null,household uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$begin
 perform 1 from public.organization_modules where organization_id=org and module_id in(select id from public.modules where key in('boss_bucks','fundraising','payments'))order by id for share;
 perform 1 from public.role_assignments where person_id=actor order by id for share;
 perform 1 from public.organization_memberships where person_id=actor and organization_id=org order by id for share;
 perform 1 from public.household_memberships where person_id=actor and household_id=household order by id for share;
 perform 1 from public.people where id=actor for share;perform 1 from public.user_accounts where person_id=actor for share;
 perform 1 from auth.users where id in(select auth_user_id from public.user_accounts where person_id=actor)for share;
end$$;
create function boss_private.discount_revision_active(p_revision uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.discount_product_revisions r join public.discount_products p on p.id=r.product_id and p.status='active'
 where r.id=p_revision and r.starts_at<=clock_timestamp()and(r.ends_at is null or r.ends_at>clock_timestamp())
 and(select e.state from public.discount_revision_events e where e.revision_id=r.id order by e.created_at desc,e.id desc limit 1)='active')
$$;
create function boss_private.discount_tier_rank(tier text)returns integer language sql immutable set search_path=''as $$select case tier when'local'then 1 when'state'then 2 when'nationwide'then 3 else 0 end$$;
create function boss_private.discount_source_valid(source uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.discount_member_sources s join public.discount_memberships m on m.id=s.membership_id and m.subject_id is not null
 and m.state not in('suspended','canceled','revoked')where s.id=source and s.starts_at<=clock_timestamp()and s.ends_at>clock_timestamp()
 and not exists(select 1 from public.discount_source_revocations v where v.source_id=s.id)
 and(s.organization_id is null or boss_private.discount_feature(s.organization_id,'discount_membership'))
 and(s.base_source_id is null or exists(select 1 from public.discount_member_sources b where b.id=s.base_source_id and b.membership_id=m.id
 and b.starts_at<=clock_timestamp()and b.ends_at>clock_timestamp()and not exists(select 1 from public.discount_source_revocations v where v.source_id=b.id))))
$$;
create function boss_private.discount_effective(member uuid)returns jsonb language sql volatile security definer set search_path=''as $$
 select jsonb_build_object('available',s.id is not null,'tier',s.tier,'source',s.kind,'starts_at',s.starts_at,'ends_at',s.ends_at,'source_id',s.id,
 'country',m.country,'region',m.region,'market',m.market,'state',case when m.state in('suspended','canceled','revoked')then m.state when m.subject_id is null then'pending_claim'
 when s.id is null then'expired'when s.kind in('fundraising_trial','physical_card_digital_trial')then'trial'else'active'end)
 from public.discount_memberships m left join lateral(select *from public.discount_member_sources where membership_id=m.id and boss_private.discount_source_valid(id)
 order by boss_private.discount_tier_rank(tier)desc,case when kind in('fundraising_trial','physical_card_digital_trial')then 0 else 1 end desc,ends_at desc,id limit 1)s on true where m.id=member
$$;
create function boss_private.discount_audit(actor uuid,org uuid,member uuid,action text,resource uuid,request uuid default null,details jsonb default '{}')returns void language plpgsql volatile security definer set search_path=''as $$begin
 insert into public.discount_membership_history(membership_id,organization_id,actor_id,action,resource_id,request_id,details)values(member,org,actor,action,resource,request,details);
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(org,actor,case when actor is not null then auth.uid()end,action,'discount_membership',coalesce(member,resource),case when org is null then'platform'else'organization'end,org,request,details);
end$$;
create function boss_private.discount_rebuild(member uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare m public.discount_memberships;s public.discount_member_sources;ent uuid;begin
 select *into m from public.discount_memberships where id=member for update;
 if m.id is null then raise exception'Membership unavailable'using errcode='PT404';end if;
 if m.subject_id is not null then for s in select *from public.discount_member_sources where membership_id=m.id order by id loop
 select entitlement_id into ent from public.discount_entitlement_links where source_id=s.id;
 if ent is null then
 insert into public.entitlements(subject_type,subject_id,entitlement_type,entitlement_key,status,starts_at,ends_at,source_type,source_id,configuration)
 values(m.subject_type,m.subject_id,'product','boss_bucks.discounts:'||s.id,case when boss_private.discount_source_valid(s.id)then'active'else'inactive'end,
 s.starts_at,s.ends_at,'discount_member_source',s.id,jsonb_build_object('membership_id',m.id,'tier',s.tier,'country',m.country,'region',m.region,'market',m.market))returning id into ent;
 insert into public.discount_entitlement_links(source_id,entitlement_id)values(s.id,ent);
 else update public.entitlements set status=case when boss_private.discount_source_valid(s.id)then'active'else'inactive'end,updated_at=clock_timestamp()where id=ent
 and status is distinct from case when boss_private.discount_source_valid(s.id)then'active'else'inactive'end;end if;
 end loop;end if;return boss_private.discount_effective(m.id);
end$$;
create function boss_private.discount_issue(p_revision uuid,kind text,key text,org uuid,campaign uuid default null,fundraiser uuid default null,donor uuid default null,
 qualification uuid default null,intent uuid default null,subject uuid default null,starts timestamptz default null,ends timestamptz default null,base uuid default null)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare r public.discount_product_revisions;m public.discount_memberships;s public.discount_member_sources;member uuid;begin
 perform pg_advisory_xact_lock(hashtextextended('boss-discount-source:'||key,0));
 select membership_id into member from public.discount_member_sources where source_key=key;if member is not null then return member;end if;
 select *into r from public.discount_product_revisions where id=p_revision;
 if r.id is null or r.organization_id is not null and r.organization_id is distinct from org or starts is null or ends is null or ends<=starts
 or kind='supporter_gift'and not exists(select 1 from public.fundraising_reward_qualifications q join public.fundraising_success_evidence e on e.id=q.evidence_id
 where q.id=qualification and q.qualified and q.status='gift_pending'and e.intent_id=intent)then raise exception'Verified product source required'using errcode='PT422';end if;
 if subject is not null then
 perform pg_advisory_xact_lock(hashtextextended('boss-discount-subject:'||r.membership_product_id||':'||r.subject_type||':'||subject||':'||r.country||':'||r.region||':'||r.market,0));
 select *into m from public.discount_memberships where product_id=r.membership_product_id and subject_type=r.subject_type and subject_id=subject and country=r.country and region=r.region and market=r.market for update;
 elsif donor is not null then
 -- Exact canonical donor lineage only. No email/mobile/household identity guess.
 select dm.*into m from public.discount_member_sources ds join public.discount_memberships dm on dm.id=ds.membership_id
 where ds.donor_id=donor and ds.campaign_id=campaign and dm.product_id=r.membership_product_id and dm.country=r.country and dm.region=r.region and dm.market=r.market order by ds.created_at,ds.id limit 1 for update of dm;
 end if;
 if m.id is null then insert into public.discount_memberships(product_id,subject_type,subject_id,country,region,market,state)
 values(r.membership_product_id,r.subject_type,subject,r.country,r.region,r.market,case when subject is null then'pending_claim'else'active'end)returning *into m;end if;
 if kind in('fundraising_trial','physical_card_digital_trial')and exists(select 1 from public.discount_member_sources ds where ds.membership_id=m.id
 and ds.kind in('fundraising_trial','physical_card_digital_trial')and ds.starts_at<=clock_timestamp()and ds.ends_at>clock_timestamp()
 and not exists(select 1 from public.discount_source_revocations v where v.source_id=ds.id))then
 raise exception'An active trial already exists for this product and subject'using errcode='PT409';end if;
 if kind='tier_upgrade'and not exists(select 1 from public.discount_member_sources b where b.id=base and b.membership_id=m.id
 and b.kind not in('tier_upgrade')and b.ends_at>=ends and b.starts_at<=starts and not exists(select 1 from public.discount_source_revocations v where v.source_id=b.id))then raise exception'Valid underlying source required'using errcode='PT409';end if;
 insert into public.discount_member_sources(membership_id,revision_id,kind,source_key,organization_id,campaign_id,fundraiser_id,donor_id,qualification_id,intent_id,tier,starts_at,ends_at,base_source_id,provenance)
 values(m.id,r.id,kind,key,org,campaign,fundraiser,donor,qualification,intent,r.tier,starts,ends,base,jsonb_build_object('product_revision_id',r.id,'qualification_id',qualification,'intent_id',intent))returning *into s;
 perform boss_private.discount_rebuild(m.id);perform boss_private.discount_audit(null,org,m.id,'membership.source.issued',s.id,null,jsonb_build_object('kind',kind,'starts_at',starts,'ends_at',ends));return m.id;
end$$;
create function boss_private.discount_revoke(source uuid,reason text,event uuid default null,actor uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$declare s public.discount_member_sources;begin
 select *into s from public.discount_member_sources where id=source;
 if s.id is null then raise exception'Source unavailable'using errcode='PT404';end if;
 perform 1 from public.discount_memberships where id=s.membership_id for update;
 insert into public.discount_source_revocations(source_id,reason,source_event_id,actor_id)values(s.id,reason,event,actor)on conflict(source_id)do nothing;
 if found then perform boss_private.discount_rebuild(s.membership_id);perform boss_private.discount_audit(actor,s.organization_id,s.membership_id,'membership.source.revoked',s.id,null,jsonb_build_object('reason',reason,'source_event_id',event));end if;
end$$;
create function boss_private.discount_claim_issue(member uuid,lifetime_seconds integer default 86400)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare secret text;c boss_private.discount_claims;m public.discount_memberships;begin
 select *into m from public.discount_memberships where id=member for update;
 if m.id is null or m.subject_id is not null or m.state<>'pending_claim'or lifetime_seconds not between 600 and 2592000 then raise exception'Pending claim required'using errcode='PT409';end if;
 update boss_private.discount_claims set revoked_at=clock_timestamp()where membership_id=m.id and claimed_at is null and revoked_at is null;
 secret:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
 insert into boss_private.discount_claims(membership_id,digest,expires_at)values(m.id,encode(sha256(convert_to(secret,'UTF8')),'hex'),clock_timestamp()+make_interval(secs=>lifetime_seconds))returning *into c;
 return jsonb_build_object('claim_id',c.id,'claim_secret',secret,'expires_at',c.expires_at);
end$$;
-- This routine is closed to every application role. An approved private delivery
-- integration may issue a secret once; normal reads can never recover it.
create function boss_private.discount_claim(actor uuid,secret text,household uuid default null)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare c boss_private.discount_claims;m public.discount_memberships;existing public.discount_memberships;subject uuid;member uuid;begin
 if coalesce(secret,'')!~'^[a-f0-9]{64}$'then raise exception'Claim unavailable'using errcode='PT404';end if;
 perform boss_private.discount_fence(actor,null,household);
 select *into c from boss_private.discount_claims where digest=encode(sha256(convert_to(secret,'UTF8')),'hex')for update;
 if c.id is null or c.revoked_at is not null or c.expires_at<=clock_timestamp()then raise exception'Claim unavailable'using errcode='PT404';end if;
 select *into m from public.discount_memberships where id=c.membership_id for update;
 perform 1 from public.organization_modules where organization_id in(select organization_id from public.discount_member_sources where membership_id=m.id)order by id for share;
 if c.claimed_by is not null then
 if c.claimed_by=actor and boss_private.discount_subject(actor,m.subject_type,m.subject_id,true)and exists(select 1 from public.discount_member_sources s where s.membership_id=m.id and boss_private.discount_source_valid(s.id))then return c.membership_id;end if;
 raise exception'Claim unavailable'using errcode='PT404';end if;
 subject:=case when m.subject_type='person'then actor else household end;
 if subject is null or not boss_private.discount_subject(actor,m.subject_type,subject,true)or m.state<>'pending_claim'
 or not exists(select 1 from public.discount_member_sources s where s.membership_id=m.id and s.starts_at<=clock_timestamp()and s.ends_at>clock_timestamp()
 and boss_private.discount_feature(s.organization_id,'discount_membership')and not exists(select 1 from public.discount_source_revocations v where v.source_id=s.id))then raise exception'Claim unavailable'using errcode='PT404';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-discount-subject:'||m.product_id||':'||m.subject_type||':'||subject||':'||m.country||':'||m.region||':'||m.market,0));
 select *into existing from public.discount_memberships where product_id=m.product_id and subject_type=m.subject_type and subject_id=subject and country=m.country and region=m.region and market=m.market for update;
 if existing.id is not null then
 if exists(select 1 from public.discount_member_sources s where s.membership_id=existing.id and s.kind in('fundraising_trial','physical_card_digital_trial')and s.starts_at<=clock_timestamp()and s.ends_at>clock_timestamp()
 and not exists(select 1 from public.discount_source_revocations v where v.source_id=s.id))and exists(select 1 from public.discount_member_sources s where s.membership_id=m.id and s.kind in('fundraising_trial','physical_card_digital_trial')and s.ends_at>clock_timestamp())then raise exception'An active trial already exists for this subject'using errcode='PT409';end if;
 update public.discount_member_sources set membership_id=existing.id where membership_id=m.id;
 update public.discount_memberships set state='canceled',updated_at=clock_timestamp(),version=version+1 where id=m.id;member:=existing.id;
 else update public.discount_memberships set subject_id=subject,state='active',updated_at=clock_timestamp(),version=version+1 where id=m.id;member:=m.id;end if;
 update boss_private.discount_claims set membership_id=member,claimed_by=actor,claimed_at=clock_timestamp()where id=c.id;
 perform boss_private.discount_rebuild(member);perform boss_private.discount_audit(actor,null,member,'membership.claimed',c.id,null,'{}');return member;
end$$;
alter table public.discount_memberships drop constraint discount_memberships_check;
alter table public.discount_memberships add constraint discount_memberships_subject_state_check check(subject_id is not null or state in('pending_claim','canceled','revoked'));

-- Snapshot campaign product policy at intent creation so future product changes
-- cannot change an already committed gift's commercial terms.
create table public.discount_intent_product_snapshots(
 intent_id uuid primary key references public.fundraising_intents(id),binding_id uuid not null references public.discount_campaign_products(id),
 revision_id uuid not null references public.discount_product_revisions(id),trial_membership_id uuid references public.discount_memberships(id),created_at timestamptz not null default clock_timestamp());
create index discount_intent_binding_idx on public.discount_intent_product_snapshots(binding_id);
create index discount_intent_revision_idx on public.discount_intent_product_snapshots(revision_id);
create index discount_intent_member_idx on public.discount_intent_product_snapshots(trial_membership_id);
alter table public.discount_intent_product_snapshots enable row level security;
revoke all on public.discount_intent_product_snapshots from public,anon,authenticated,service_role,boss_payment_worker;
create function boss_private.discount_snapshot_intent()returns trigger language plpgsql volatile security definer set search_path=''as $$declare b public.discount_campaign_products;begin
 select *into b from public.discount_campaign_products where campaign_id=new.campaign_id and gift_enabled and status='active'and starts_at<=clock_timestamp()
 and(ends_at is null or ends_at>clock_timestamp())and boss_private.discount_revision_active(revision_id)order by created_at desc,id desc limit 1;
 if b.id is not null then insert into public.discount_intent_product_snapshots(intent_id,binding_id,revision_id)values(new.id,b.id,b.revision_id);end if;return new;
end$$;
create trigger discount_intent_snapshot after insert on public.fundraising_intents for each row execute function boss_private.discount_snapshot_intent();
create function boss_private.discount_gift_qualification()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare e public.fundraising_success_evidence;i public.fundraising_intents;r public.discount_product_revisions;org uuid;begin
 if not new.qualified or new.status<>'gift_pending'then return new;end if;
 select *into e from public.fundraising_success_evidence where id=new.evidence_id;select *into i from public.fundraising_intents where id=e.intent_id;
 select dr.*into r from public.discount_intent_product_snapshots ds join public.discount_product_revisions dr on dr.id=ds.revision_id where ds.intent_id=i.id;
 select organization_id into org from public.fundraising_campaigns where id=i.campaign_id;
 if r.id is not null and r.gift_enabled and r.term_days is not null then
 perform boss_private.discount_issue(r.id,'supporter_gift','gift:'||new.id,org,i.campaign_id,i.fundraiser_id,i.donor_id,new.id,i.id,null,e.payment_success_at,e.payment_success_at+make_interval(days=>r.term_days));end if;return new;
end$$;
create trigger discount_gift_qualifies after insert on public.fundraising_reward_qualifications for each row execute function boss_private.discount_gift_qualification();
create function boss_private.discount_gift_reversal()returns trigger language plpgsql volatile security definer set search_path=''as $$declare s record;begin
 if new.state in('refunded','partially_refunded','chargeback','canceled')then
 for s in select ds.id,q.policy from public.discount_member_sources ds join public.fundraising_reward_qualifications q on q.id=ds.qualification_id where ds.intent_id=new.intent_id loop
 if new.state in('refunded','chargeback','canceled')or new.remaining_valid_amount_minor<=(s.policy->>'threshold_minor')::bigint then
 perform boss_private.discount_revoke(s.id,'gift_reversal',new.id);end if;end loop;end if;return new;
end$$;
create trigger discount_gift_corrects after insert on public.fundraising_intent_events for each row execute function boss_private.discount_gift_reversal();

do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'discount_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;end$$;
