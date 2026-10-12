-- Context-specific checks; role mapping supplies potential capability only.
create function boss_private.fundraising_module(org uuid,k text)returns boolean language sql volatile security definer set search_path=''as $$
 select k in('fundraising','money_board')and exists(select 1 from public.organization_modules m join public.modules c on c.id=m.module_id and c.key=k and c.status='active'join public.organizations o on o.id=m.organization_id and o.status='active'
 where m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
$$;
create function boss_private.fundraising_role(actor uuid,k text,org uuid,unit uuid default null,team uuid default null)returns boolean language sql volatile security definer set search_path=''as $$
 select k in('fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage')
 and exists(select 1 from public.people where id=actor and status='active')and exists(select 1 from public.organizations where id=org and status='active')
 and(team is null or exists(select 1 from public.teams t where t.id=team and t.organization_id=org and t.status='active'and t.parent_unit_id is not distinct from unit))
 and(unit is null or exists(select 1 from public.organization_units u where u.id=unit and u.organization_id=org and u.status='active'))
 and exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.key=k and p.status='active'
 where a.person_id=actor and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and(
 a.scope_type='platform'and a.scope_id is null and a.organization_id is null and(r.key in('super_administrator','platform_administrator')or exists(select 1 from public.organization_memberships m where m.person_id=actor and m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())))
 or a.organization_id=org and(
 a.scope_type='organization'and a.scope_id=org and exists(select 1 from public.organization_memberships m where m.person_id=actor and m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
 or a.scope_type='organization_unit'and unit is not null and a.scope_id=unit and exists(select 1 from public.organization_memberships m where m.person_id=actor and m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
 or a.scope_type='team'and team is not null and a.scope_id=team and exists(select 1 from public.team_memberships m where m.person_id=actor and m.team_id=team and m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())))))
$$;
create function boss_private.fundraising_guardian(actor uuid,subject uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.people where id=actor and status='active')and exists(select 1 from public.guardian_relationships g where g.guardian_person_id=actor and g.dependent_person_id=subject and g.can_manage_fundraising and g.authority_status='active'and g.verified_at<=clock_timestamp()and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp()))
$$;
create function boss_private.fundraising_self(actor uuid,subject uuid,c public.fundraising_campaigns)returns boolean language sql volatile security definer set search_path=''as $$
 select actor=subject and c.allow_adult_self_sharing and exists(select 1 from public.people p where p.id=subject and p.status='active'and p.date_of_birth is not null and p.date_of_birth<=current_date-interval'18 years')
$$;
create function boss_private.fundraising_eligible(f public.fundraising_fundraisers)returns boolean language sql volatile security definer set search_path=''as $$
 select f.status in('pending','active')and f.starts_at<=clock_timestamp()and(f.ends_at is null or f.ends_at>clock_timestamp())
 and exists(select 1 from public.participants p join public.people person on person.id=p.person_id and person.status='active'where p.id=f.participant_id and p.person_id=f.person_id and p.status='active')
 and exists(select 1 from public.organization_memberships m where m.organization_id=f.organization_id and m.person_id=f.person_id and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
 and(f.team_id is null or exists(select 1 from public.team_memberships m where m.organization_id=f.organization_id and m.team_id=f.team_id and m.person_id=f.person_id and m.participant_id=f.participant_id and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())))
$$;
create function boss_private.fundraising_member(f public.fundraising_fundraisers)returns boolean language sql volatile security definer set search_path=''as $$select f.status='active'and boss_private.fundraising_eligible(f)$$;
create function boss_private.fundraising_related(actor uuid,f public.fundraising_fundraisers)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.fundraising_eligible(f)and(boss_private.fundraising_guardian(actor,f.person_id)or boss_private.fundraising_self(actor,f.person_id,c))from public.fundraising_campaigns c where c.id=f.campaign_id
$$;
create function boss_private.fundraising_view(actor uuid,f public.fundraising_fundraisers)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.fundraising_module(f.organization_id,'fundraising')and(boss_private.fundraising_role(actor,'fundraising.view',f.organization_id,f.unit_id,f.team_id)or boss_private.fundraising_related(actor,f))
$$;
-- Fixed parent-first domain lock; authority/module rows are held until commit.
-- A revocation that wins the lock is observed by the post-lock clock-time check.
create function boss_private.fundraising_fence(org uuid,actor uuid default null,subject uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$
 begin
 perform 1 from public.organization_modules where organization_id=org and module_id in(select id from public.modules where key in('fundraising','money_board'))order by id for share;
 perform 1 from public.organization_memberships where organization_id=org and(person_id=actor or person_id=subject)order by id for share;
 perform 1 from public.team_memberships where organization_id=org and(person_id=actor or person_id=subject)order by id for share;
 perform 1 from public.role_assignments where person_id=actor order by id for share;
 perform 1 from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=subject order by id for share;
 end$$;
create function boss_private.fundraising_active(c public.fundraising_campaigns)returns boolean language sql volatile security definer set search_path=''as $$
 select c.status in('active','scheduled')and c.public_visible and c.starts_at<=clock_timestamp()and c.ends_at>clock_timestamp()and boss_private.fundraising_module(c.organization_id,'fundraising')
$$;
create function boss_private.fundraising_reward_valid(p jsonb,currency text)returns boolean language sql immutable set search_path=''as $$
 select p='{}'::jsonb or(jsonb_typeof(p)='object'and p?&array['currency','threshold_minor','comparison','trial_days']and not exists(select 1 from jsonb_object_keys(p)k where k<>all(array['currency','threshold_minor','comparison','trial_days']))
 and p->>'currency'=currency and p->>'comparison'='gt'and jsonb_typeof(p->'threshold_minor')='number'and(p->>'threshold_minor')~'^[0-9]+$'and(p->>'threshold_minor')::numeric between 1 and 1000000000000 and(p->>'trial_days')in('30','60','90'))
$$;
create function boss_private.fundraising_audit(actor uuid,campaign uuid,fundraiser uuid,action text,request uuid,details jsonb default '{}')returns void language plpgsql volatile security definer set search_path=''as $$
 begin
 insert into public.fundraising_history(campaign_id,fundraiser_id,action,actor_person_id,request_id,details)values(campaign,fundraiser,action,actor,request,details);
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 select organization_id,actor,case when actor is null then null else auth.uid()end,action,'fundraising_campaign',campaign,'organization',organization_id,request,details from public.fundraising_campaigns where id=campaign;
 end$$;
-- Non-public helpers. The only callable helpers below are closed RPC implementations.
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'fundraising_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
