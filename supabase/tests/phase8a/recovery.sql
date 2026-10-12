\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir fixture.sql
create temp table recovery_baseline as select
 (select md5(string_agg((to_jsonb(x)-'updated_at')::text,'|'order by id))from public.role_assignments x) roles,
 (select md5(string_agg(to_jsonb(x)::text,'|'order by id))from public.organization_modules x) modules,
 (select md5(string_agg(to_jsonb(x)::text,'|'order by id))from public.guardian_relationships x) guardians,
 (select md5(string_agg(to_jsonb(x)::text,'|'order by id))from public.household_memberships x) households;
-- Status changes retain immutable audit history and advance tracking updated_at.
-- Compare every original role business field while allowing that tracking timestamp.
-- Simulate the approved restricted stage, then recover the administrator first.
update public.role_assignments set status='inactive'where person_id=pg_temp.f('admin')and role_id=(select id from public.roles where key='platform_administrator');
update public.role_assignments set status='active'where person_id=pg_temp.f('admin')and role_id=(select id from public.roles where key='platform_administrator');
select pg_temp.check('administrator restored before resource cleanup','RECOVERY',boss_private.merchant_platform(pg_temp.f('admin'),'merchant_reviews.manage'));
update public.merchant_access_assignments set status='ended',ends_at=greatest(starts_at+interval'1 microsecond',clock_timestamp())where merchant_id=pg_temp.mid('merchant','merchant_id');
update public.merchant_staff_assignments set status='ended',ends_at=greatest(starts_at+interval'1 microsecond',clock_timestamp())where merchant_id=pg_temp.mid('merchant','merchant_id');
update public.merchant_sales_assignments set status='ended',ends_at=greatest(starts_at+interval'1 microsecond',clock_timestamp());
update boss_private.merchant_redemption_intents set retired_at=clock_timestamp()where merchant_id=pg_temp.mid('merchant','merchant_id')and retired_at is null;
insert into public.merchant_offer_events(revision_id,state,reason,actor_id)select id,'archived','Disposable controlled recovery',pg_temp.f('admin')from public.merchant_offer_revisions where merchant_id=pg_temp.mid('merchant','merchant_id');
update public.merchant_offer_families set status='archived'where merchant_id=pg_temp.mid('merchant','merchant_id');
update public.merchant_locations set status='archived'where merchant_id=pg_temp.mid('merchant','merchant_id');
update public.merchants set status='archived'where id=pg_temp.mid('merchant','merchant_id');
update public.merchant_modules set status='inactive',configuration='{}',ends_at=greatest(starts_at+interval'1 microsecond',clock_timestamp())where merchant_id=pg_temp.mid('merchant','merchant_id');
select boss_private.discount_revoke(id,'revoked',null,pg_temp.f('admin'))from public.discount_member_sources where membership_id=pg_temp.did('member-trial');
update public.notification_events set status='canceled'where source_type='merchant_history'and merchant_id=pg_temp.mid('merchant','merchant_id')and status in('queued','processing','failed');
update boss_private.notification_expansion_jobs set status='complete',processing_until=null where notification_event_id in(select id from public.notification_events where source_type='merchant_history'and merchant_id=pg_temp.mid('merchant','merchant_id'))and status in('queued','processing','failed');
update public.notification_deliveries set status='canceled',processing_until=null,failure_category='authority_removed'where status in('queued','processing')and notification_id in(select n.id from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.source_type='merchant_history'and e.merchant_id=pg_temp.mid('merchant','merchant_id'));
select boss_private.merchant_audit(pg_temp.f('admin'),pg_temp.mid('merchant','merchant_id'),'acceptance.recovered',pg_temp.mid('merchant','merchant_id'),null);
select pg_temp.check('exact original roles restored','RECOVERY',(select roles=(select md5(string_agg((to_jsonb(x)-'updated_at')::text,'|'order by id))from public.role_assignments x)from recovery_baseline));
select pg_temp.check('exact original modules preserved','RECOVERY',(select modules=(select md5(string_agg(to_jsonb(x)::text,'|'order by id))from public.organization_modules x)from recovery_baseline));
select pg_temp.check('guardians preserved','RECOVERY',(select guardians is not distinct from(select md5(string_agg(to_jsonb(x)::text,'|'order by id))from public.guardian_relationships x)from recovery_baseline));
select pg_temp.check('households preserved','RECOVERY',(select households=(select md5(string_agg(to_jsonb(x)::text,'|'order by id))from public.household_memberships x)from recovery_baseline));
select pg_temp.check('no residual scoped merchant authority','RECOVERY',not exists(select 1 from public.merchant_access_assignments where merchant_id=pg_temp.mid('merchant','merchant_id')and status='active'));
select pg_temp.check('archived resource unavailable','RECOVERY',not boss_private.merchant_available(pg_temp.mid('offer'),pg_temp.mid('loc-a')));
select pg_temp.check('no active commerce configuration','RECOVERY',not boss_private.merchant_feature(pg_temp.mid('merchant','merchant_id'),'offers'));
select pg_temp.check('history preserved','RECOVERY',exists(select 1 from public.merchant_history where merchant_id=pg_temp.mid('merchant','merchant_id')and action='acceptance.recovered'));
select pg_temp.check('new trial source revoked','RECOVERY',not exists(select 1 from public.discount_member_sources where membership_id=pg_temp.did('member-trial')and boss_private.discount_source_valid(id)));
select pg_temp.check('all exact proofs retired','RECOVERY',not exists(select 1 from boss_private.merchant_redemption_intents where merchant_id=pg_temp.mid('merchant','merchant_id')and retired_at is null));
select pg_temp.check('no exact pending notification work','RECOVERY',not exists(select 1 from public.notification_events where merchant_id=pg_temp.mid('merchant','merchant_id')and status in('queued','processing'))and not exists(select 1 from boss_private.notification_expansion_jobs j join public.notification_events e on e.id=j.notification_event_id where e.merchant_id=pg_temp.mid('merchant','merchant_id')and j.status in('queued','processing')));
set constraints all immediate;
select 12 recovery_assertions,'Phase 8A administrator-first exact recovery' suite;
rollback;
