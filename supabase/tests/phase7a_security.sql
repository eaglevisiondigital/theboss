\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7a/fixture.sql
-- New FK coverage is additive; no historical index assertion is excluded.
do $$declare c record;missing text[]:=array[]::text[];begin for c in select fk.*from pg_constraint fk join pg_class t on t.oid=fk.conrelid where fk.contype='f'and(t.relname like'fundraising_%'or t.relname like'money_board_%')loop
 if not exists(select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and i.indpred is null and i.indexprs is null and i.indnkeyatts>=cardinality(c.conkey)and(i.indkey::smallint[])[0:cardinality(c.conkey)-1]@>c.conkey)then missing:=array_append(missing,c.conrelid::regclass||'.'||c.conname);end if;
 end loop;perform pg_temp.check('all FK indexes: '||array_to_string(missing,', '),'INDEX',cardinality(missing)=0);end$$;
select pg_temp.check('seven exact phase keys','PERMISSIONS',(select count(*)=7 from public.permissions where key in('fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage')));
select pg_temp.check('all management potential maps only approved administrators','PERMISSIONS',not exists(select 1 from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where p.key in('fundraising.create','fundraising.manage','fundraising.publish','money_board.manage')and r.key not in('super_administrator','platform_administrator','organization_owner','organization_administrator')));
select pg_temp.check('progress mappings no private finance for coaches','PERMISSIONS',not exists(select 1 from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.permissions p on p.id=rp.permission_id where p.key='fundraising.financial_view'and r.key in('head_coach','team_administrator','program_administrator','athletic_director')));
select pg_temp.check('all fundraising helper search paths empty','ACL',not exists(select 1 from pg_proc p where p.pronamespace in('boss_private'::regnamespace,'boss_fundraising_public'::regnamespace)and(p.proname like'fundraising_%'or p.pronamespace='boss_fundraising_public'::regnamespace)and not coalesce('search_path=""'=any(p.proconfig),false)));
select pg_temp.check('no PUBLIC funding execution','ACL',not exists(select 1 from pg_proc p where p.pronamespace in('boss_private'::regnamespace,'boss_fundraising_public'::regnamespace)and(p.proname like'fundraising_%'or p.pronamespace='boss_fundraising_public'::regnamespace)and exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE')));
select pg_temp.check('anonymous private schema remains closed','ACL',not has_schema_privilege('anon','boss_private','usage'));
select pg_temp.check('only two anonymous fundraising helpers','ACL',(select count(*)=2 from pg_proc where pronamespace='boss_fundraising_public'::regnamespace));
update public.organization_modules set status='inactive'where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key in('sports','calendar'));
set local role anon;
select pg_temp.check('non-sport fundraising still available','MODULE',public.boss_fundraising_public(pg_temp.fpath('share'))->'campaign'->>'name'='Synthetic fundraising');reset role;
update public.organization_modules set status='inactive'where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='money_board');
set local role anon;select pg_temp.check('money board independently disabled','MODULE',public.boss_fundraising_public(pg_temp.fpath('share'))->'board'='null'::jsonb);reset role;
update public.organization_modules set status='active'where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='money_board');
update public.team_memberships set status='inactive'where id=pg_temp.f('membership-coach');
set local role authenticated;select pg_temp.actor('coach');select pg_temp.denied('ended staff membership removes team view',format('select public.boss_fundraising_read(%L::jsonb)',jsonb_build_object('organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'))),'PT403');reset role;
update public.team_memberships set status='inactive'where id=pg_temp.f('membership-child1');set local role anon;select pg_temp.denied('ended athlete team removes public share',format('select public.boss_fundraising_public(%L)',pg_temp.fpath('share')),'PT404');reset role;
update public.team_memberships set status='active'where id=pg_temp.f('membership-child1');
set local role authenticated;select pg_temp.actor('child1');select pg_temp.check('Auth account without self policy gives no family authority','SELF',jsonb_array_length(public.boss_fundraising_read('{"mode":"family"}')->'campaigns')=0);reset role;
update public.fundraising_campaigns set allow_adult_self_sharing=true where id=pg_temp.fid('campaign');
set local role authenticated;select pg_temp.actor('child1');select pg_temp.check('missing DOB gives no self authority','SELF',jsonb_array_length(public.boss_fundraising_read('{"mode":"family"}')->'campaigns')=0);reset role;
select pg_temp.check('canonical existing admin capability extension present','GUARDIAN',position('can_manage_fundraising=case' in pg_get_functiondef('boss_private.admin_mutate_command(text,jsonb,uuid,uuid,boolean,uuid)'::regprocedure))>0);
select pg_temp.check('RLS private source tables','ACL',(select bool_and(relrowsecurity)from pg_class where relnamespace='boss_private'::regnamespace and relname in('fundraising_receipts','fundraising_guest_receipts','fundraising_rate_windows','fundraising_milestones')));
select count(*)passed_assertions from pg_temp.phase5a_assertions;rollback;
