\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8b1/fixture.sql
-- Hash all original public business relations except consequential audit/history.
create temp table partner_original_baseline(name text primary key,value text);
do $$declare t text;v text;begin for t in select tablename from pg_tables where schemaname='public'and tablename not like'partner_%'and tablename not in('audit_events')loop
 execute format('select md5(coalesce(string_agg(to_jsonb(r)::text,''|''order by to_jsonb(r)::text),''''))from public.%I r',t)into v;insert into partner_original_baseline values(t,v);end loop;end$$;
select pg_temp.check('exact approved six permissions','PERMISSION',(select count(*)=6 from public.permissions where key like'partners.%'));
select pg_temp.check('no ordinary merchant role receives permission','PERMISSION',not exists(select 1 from public.role_permissions rp join public.permissions p on p.id=rp.permission_id join public.roles r on r.id=rp.role_id where p.key like'partners.%'and r.key not in('super_administrator','platform_administrator')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.pm('withdraw-authority','catalog.withdraw',pg_temp.pi(jsonb_build_object('source_id',pg_temp.pid('source'))));reset role;
savepoint controlled_authority;
update public.role_assignments set status='inactive'where person_id=pg_temp.f('admin')and scope_type='platform';
set local role authenticated;
select pg_temp.denied('receipt replay checks current platform role',format('select pg_temp.pm(''withdraw-authority'',''catalog.withdraw'',%L)',pg_temp.pi(jsonb_build_object('source_id',pg_temp.pid('source')))));
select pg_temp.actor('parent');select pg_temp.denied('native merchant owner cannot activate provider',format('select pg_temp.pm(''owner-activate'',''integration.activate'',%L)',pg_temp.pi()));reset role;
update public.role_assignments set status='active'where person_id=pg_temp.f('admin')and scope_type='platform';
set local role authenticated;select pg_temp.actor('admin');select pg_temp.check('administrator recovery before other work','RECOVERY',jsonb_array_length(public.boss_partners_read()->'providers')=2);reset role;
-- Recovery was exercised above. Rewind only the local role-change savepoint to
-- preserve the exact pre-test row metadata while retaining the test evidence.
rollback to savepoint controlled_authority;
select pg_temp.check('administrator valid after baseline rewind','RECOVERY',exists(select 1 from public.role_assignments where person_id=pg_temp.f('admin')and scope_type='platform'and status='active'));
-- End exact territory, suspend contract, archive provider; retain audited rows.
set local role authenticated;
select pg_temp.pm('recover-territory','territory.end',pg_temp.pi(jsonb_build_object('territory_id',pg_temp.pid('territory'))));
select pg_temp.pm('recover-contract','contract.review',pg_temp.pi(jsonb_build_object('contract_id',pg_temp.pid('contract'),'state','terminated','approval_reference','Synthetic documented cleanup')));
select pg_temp.pm('recover-provider','provider.state',pg_temp.pi('{"expected_version":5,"state":"archived","reason":"Synthetic explicit recovery archive"}'));reset role;
select pg_temp.check('restored no active temporary adapter','RECOVERY',not exists(select 1 from public.partner_config_revisions where operational or credentials_ready));
select pg_temp.check('controlled provider archived','RECOVERY',(select state='archived'from public.partner_providers where id=pg_temp.pid('provider')));
select pg_temp.check('controlled territory ended','RECOVERY',(select status='ended'from public.partner_territories where id=pg_temp.pid('territory')));
select pg_temp.check('licensing inactive after recovery','RECOVERY',not boss_private.partner_contract_active(pg_temp.pid('contract')));
select pg_temp.check('no current consumer access','RECOVERY',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'visible')::boolean);
select pg_temp.check('no partner pending notification/work','RECOVERY',not exists(select 1 from public.partner_catalog_snapshots where status='open'));
-- Restore the selected role baseline used solely to test stale authority.
do $$declare t record;v text;begin for t in select *from partner_original_baseline loop
 execute format('select md5(coalesce(string_agg(to_jsonb(r)::text,''|''order by to_jsonb(r)::text),''''))from public.%I r',t.name)into v;
 perform pg_temp.check('original '||t.name||' baseline equal','BASELINE',v=t.value);end loop;end$$;
select pg_temp.check('audit creation and removal present','AUDIT',(select count(*)>=3 from public.audit_events where resource_type='partner_provider'));
select pg_temp.denied('archive prevents new synthetic catalog',format('select pg_temp.feed(''after-archive'',2,''delta'',%L)','[]'::jsonb),'PT409');
set constraints all immediate;
select count(*)passed_assertions,'Phase 8B1 authority lifecycle/recovery/baselines'::text suite from phase5a_assertions;rollback;
