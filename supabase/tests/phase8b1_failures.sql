\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8b1/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.feed('malformed-format',2,'full',jsonb_build_array(pg_temp.item('survives'),pg_temp.item('bad-date',1,'{"starts_at":"malformed date"}'),null,pg_temp.item('bad-field',1,'{"injected_field":"unexpected"}')));
reset role;
select pg_temp.check('invalid date and malformed peers quarantined independently','IMPORT',(select accepted=1 and quarantined=3 and withdrawn=0 from public.partner_import_runs where id=pg_temp.pid('malformed-format')));
select pg_temp.check('valid peer committed exactly once','IMPORT',(select count(*)=1 from public.partner_benefit_sources where provider_id=pg_temp.pid('provider')and external_id='survives'));
select pg_temp.check('invalid full retained original source','IMPORT',(select status='available'from public.partner_benefit_sources where id=pg_temp.pid('source')));
select pg_temp.check('quarantine has only safe finite failure categories','PRIVACY',(select count(*)=3 from public.partner_import_quarantine where run_id=pg_temp.pid('malformed-format')and category='invalid_item'));
set constraints all immediate;
select count(*)passed_assertions,'Phase 8B1 malformed feed partial-failure isolation'::text suite from phase5a_assertions;rollback;
