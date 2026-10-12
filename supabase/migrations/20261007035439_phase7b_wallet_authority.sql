-- No raw client ACL; narrowly scoped private implementations power INVOKER RPCs.
create function boss_private.bucks_feature(org uuid,feature text)returns boolean language sql volatile security definer set search_path=''as $$
 select feature in('wallet','fundraising_issuance','family_wallet','organization_wallet_reporting','charge_eligibility_preview')and exists(
 select 1 from public.organization_modules m join public.modules k on k.id=m.module_id and k.key='boss_bucks' and k.status='active'
 join public.organizations o on o.id=m.organization_id and o.status='active'where m.organization_id=org and m.status='active'
 and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())and m.configuration->'wallet'='true'::jsonb and m.configuration->feature='true'::jsonb)
$$;
create function boss_private.bucks_role(actor uuid,permission text,org uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select permission in('boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage')and exists(select 1 from public.people where id=actor and status='active')
 and exists(select 1 from public.organizations where id=org and status='active')and exists(
 select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'join public.role_permissions rp on rp.role_id=r.id
 join public.permissions p on p.id=rp.permission_id and p.key=permission and p.status='active'where a.person_id=actor and a.status='active'
 and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and(
 a.scope_type='platform'and a.scope_id is null and a.organization_id is null and r.key in('super_administrator','platform_administrator')
 or a.scope_type='organization'and a.organization_id=org and a.scope_id=org and exists(select 1 from public.organization_memberships m where m.person_id=actor and m.organization_id=org
 and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))))
$$;
create function boss_private.bucks_household_member(actor uuid,household uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.household_memberships m join public.households h on h.id=m.household_id and h.status='active'join public.people p on p.id=m.person_id and p.status='active'
 where m.household_id=household and m.person_id=actor and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
$$;
create function boss_private.bucks_guardian(actor uuid,subject uuid,household uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.bucks_household_member(actor,household)and boss_private.bucks_household_member(subject,household)and exists(
 select 1 from public.guardian_relationships g where g.guardian_person_id=actor and g.dependent_person_id=subject and g.can_manage_boss_bucks
 and g.authority_status='active'and g.verified_at<=clock_timestamp()and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp()))
$$;
create function boss_private.bucks_accessible(actor uuid,wallet uuid,manager boolean default false)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.boss_bucks_access a join public.boss_bucks_wallets w on w.id=a.wallet_id and w.status='active'
 join public.guardian_relationships g on g.id=a.guardian_relationship_id and g.guardian_person_id=a.person_id
 where a.person_id=actor and a.wallet_id=wallet and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())
 and(not manager or a.access_kind='manager')and boss_private.bucks_feature(a.organization_id,'family_wallet')and boss_private.bucks_guardian(actor,g.dependent_person_id,w.household_id)
 and g.can_manage_boss_bucks and g.authority_status='active'and g.verified_at<=clock_timestamp()and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp()))
$$;
create function boss_private.bucks_fence(actor uuid,org uuid default null,wallet uuid default null,household uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$begin
 perform 1 from public.organization_modules m where module_id in(select id from public.modules where key='boss_bucks')
 and(organization_id=org or organization_id in(select organization_id from public.boss_bucks_access a where a.wallet_id=wallet and a.person_id=actor))order by id for share;
 perform 1 from public.role_assignments where person_id=actor order by id for share;
 perform 1 from public.organization_memberships where person_id=actor and organization_id=org order by id for share;
 perform 1 from public.guardian_relationships where guardian_person_id=actor order by id for share;
 perform 1 from public.household_memberships where household_id=household or household_id in(select household_id from public.boss_bucks_wallets where id=wallet)order by id for share;
 perform 1 from public.boss_bucks_access where person_id=actor and(wallet is null or wallet_id=wallet)order by id for share;
 perform 1 from public.boss_bucks_wallets where id=wallet for share;
end$$;
create function boss_private.bucks_audit(actor uuid,action text,org uuid,wallet uuid,grant_id uuid default null,request uuid default null,details jsonb default '{}')returns void language plpgsql volatile security definer set search_path=''as $$begin
 insert into public.boss_bucks_history(organization_id,wallet_id,grant_id,actor_person_id,action,request_id,details)values(org,wallet,grant_id,actor,action,request,details);
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(org,actor,case when actor is not null then auth.uid()end,action,'boss_bucks_wallet',coalesce(wallet,grant_id),case when org is not null then 'organization'else 'platform'end,org,request,details);
end$$;
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
