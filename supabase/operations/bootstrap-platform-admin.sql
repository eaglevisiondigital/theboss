-- Trusted operator only. Never expose as a client RPC or run at application
-- startup. Requires a separately approved identity and platform-administrator
-- grant. Passwords, tokens, sessions and user metadata are never consulted.
-- psql usage: -v bootstrap_email=<operator-approved email>
-- Optional: -v bootstrap_person_id=<explicit reviewed canonical person UUID>
\if :{?bootstrap_person_id}
\else
\set bootstrap_person_id ''
\endif
begin;
select set_config('boss.bootstrap_email', :'bootstrap_email', true) is not null as bootstrap_input_set;
select set_config('boss.bootstrap_person_id', :'bootstrap_person_id', true) is not null as canonical_input_set;
do $$
declare
  auth_id uuid; v_person uuid; account_id uuid; v_role uuid; assignment_id uuid;
  explicit_person uuid:=nullif(current_setting('boss.bootstrap_person_id',true),'')::uuid;
  request_id uuid:=gen_random_uuid(); identity_count integer;
begin
  select count(*),min(id::text)::uuid into identity_count,auth_id from auth.users
    where lower(email)=lower(current_setting('boss.bootstrap_email')) and email_confirmed_at is not null
      and not coalesce(is_anonymous,false) and deleted_at is null and (banned_until is null or banned_until<=now());
  if identity_count<>1 then raise exception 'Exactly one verified approved Auth identity is required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('auth-link:'||auth_id::text,0));
  select a.id,a.person_id into account_id,v_person from public.user_accounts a where a.auth_user_id=auth_id;
  if account_id is not null then
    if explicit_person is not null and v_person<>explicit_person then raise exception 'Existing mapping cannot be rebound'; end if;
    if not exists(select 1 from public.user_accounts a join public.people p on p.id=a.person_id
      where a.id=account_id and a.account_status='active' and p.status='active') then raise exception 'Existing mapping requires reviewed remediation'; end if;
  else
    if explicit_person is not null then
      if not exists(select 1 from public.people p where p.id=explicit_person and p.status='active') then raise exception 'Reviewed person is unavailable'; end if;
      v_person:=explicit_person;
    else
      if exists(select 1 from public.people p where lower(p.primary_email)=lower(current_setting('boss.bootstrap_email'))) then
        raise exception 'Possible existing person requires explicit canonical review';
      end if;
      insert into public.people(display_name) values('Boss controlled administrator') returning id into v_person;
      insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
        values(v_person,auth_id,'identity.bootstrap','person',v_person,'person',v_person,request_id,jsonb_build_object('procedure','approved_operator_bootstrap'));
    end if;
    if exists(select 1 from public.user_accounts a where a.person_id=v_person and a.account_status='active') then raise exception 'Canonical person already has an active account'; end if;
    insert into public.user_accounts(auth_user_id,person_id,account_status) values(auth_id,v_person,'active') returning id into account_id;
    insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
      values(v_person,auth_id,'account.link','user_account',account_id,'person',v_person,request_id,jsonb_build_object('procedure','approved_operator_bootstrap'));
  end if;
  select r.id into v_role from public.roles r where r.key='platform_administrator' and r.status='active' and 'platform'=any(r.allowed_scope_types);
  if v_role is null then raise exception 'Approved platform role is unavailable'; end if;
  -- Serialize competing bootstrap grants across identities for the same person.
  update public.people p set updated_at=updated_at where p.id=v_person;
  if not exists(select 1 from public.role_assignments a where a.person_id=v_person and a.role_id=v_role
    and a.scope_type='platform' and a.status='active' and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())) then
    if exists(select 1 from public.role_assignments a where a.person_id=v_person and a.role_id=v_role
      and a.scope_type='platform' and a.status='active' and a.starts_at>now()) then
      raise exception 'Scheduled platform grant requires reviewed remediation';
    end if;
    insert into public.role_assignments(person_id,role_id,scope_type,status,granted_by_person_id)
      values(v_person,v_role,'platform','active',v_person) returning id into assignment_id;
    insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,request_id,after_data)
      values(v_person,auth_id,'role_assignment.add','role_assignment',assignment_id,'platform',request_id,jsonb_build_object('procedure','approved_operator_bootstrap','role_key','platform_administrator'));
  end if;
end $$;
select 'approved bootstrap completed without credential inspection' as bootstrap_result;
commit;
