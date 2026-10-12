-- Disposable synthetic fixture only; no canonical success is manufactured.
\ir ../phase7b/fixture.sql
update public.organization_modules set configuration=configuration||'{"wallet_spending":true,"charge_payments":true,"split_tender":true}'::jsonb
 where module_id in(select id from public.modules where key='boss_bucks');
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
 select pg_temp.f(label),id,'active','{"registration":true,"fees":true,"offline_payments":true,"payment_plans":true}'::jsonb,now()-interval'1 day'
 from unnest(array['org','other-org'])label cross join public.modules where key='registration';
create function pg_temp.charge(label text,org_label text default 'org',child_label text default 'child1',currency text default 'USD',amount bigint default 10000)returns uuid language plpgsql as $$begin
 insert into public.registration_offerings(id,organization_id,title,scope_type,scope_id,created_by_person_id,updated_by_person_id)
 values(pg_temp.f('offering-'||label),pg_temp.f(org_label),'Synthetic '||label,'organization',pg_temp.f(org_label),pg_temp.f('admin'),pg_temp.f('admin'));
 insert into public.registrations(id,organization_id,offering_id,participant_id,household_id,submitted_by_person_id,offering_snapshot,participant_snapshot)
 values(pg_temp.f('registration-'||label),pg_temp.f(org_label),pg_temp.f('offering-'||label),pg_temp.f('participant-'||child_label),pg_temp.f('household'),pg_temp.f('parent'),'{}','{}');
 insert into public.charges(id,organization_id,registration_id,participant_id,household_id,title,charge_type,original_amount_minor,currency,created_by_person_id)
 values(pg_temp.f('charge-'||label),pg_temp.f(org_label),pg_temp.f('registration-'||label),pg_temp.f('participant-'||child_label),pg_temp.f('household'),'Synthetic '||label,label,amount,currency,pg_temp.f('admin'));
 return pg_temp.f('charge-'||label);
end$$;
select pg_temp.charge('camp');select pg_temp.charge('gear');select pg_temp.charge('travel');select pg_temp.charge('church');
select pg_temp.charge('other','other-org');select pg_temp.charge('unrelated-child','org','child2');select pg_temp.charge('currency','org','child1','CAD');
create temp table payment_results(label text primary key,result jsonb);
grant all on payment_results to authenticated;
create function pg_temp.spend_input(amount bigint,label text default 'camp')returns jsonb language sql as $$select jsonb_build_object(
 'wallet_id',pg_temp.w(),'organization_id',pg_temp.f('org'),'currency','USD','amount_minor',amount,
 'allocations',jsonb_build_array(jsonb_build_object('charge_id',pg_temp.f('charge-'||label),'amount_minor',amount)))$$;
grant execute on function pg_temp.spend_input(bigint,text)to authenticated,anon;
