\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7b/fixture.sql
select pg_temp.success('no-expiry',2000);
select pg_temp.check('no expiry by default','POLICY',(select expires_at is null from public.boss_bucks_grants limit 1));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support'),'expiry_seconds',1));reset role;
select pg_temp.success('expiry',3000);
select pg_temp.check('later policy never rewrites old grant','POLICY',(select g.amount_minor=1000 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='no-expiry'));
select pg_sleep(1.05);
select pg_temp.check('expired value excluded before materialization','EXPIRY',boss_private.bucks_available(pg_temp.w())=1000);
select pg_temp.check('expiration appends balanced journal once','EXPIRY',boss_private.bucks_expire()=1 and boss_private.bucks_expire()=0);
set constraints all immediate;set constraints all deferred;
select pg_temp.check('expiration preserves attribution','EXPIRY',(select count(*)=2 from public.boss_bucks_grants)and(select count(*)=1 from public.boss_bucks_journals where kind='expiration'));
select pg_temp.check('rebuild after expiry exact','REBUILD',boss_private.bucks_rebuild(pg_temp.w())->0->>'available_minor'='1000');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','none','basis_points',0,'currency','USD','channels',jsonb_build_array('direct_support')));reset role;
select pg_temp.success('disabled',4000);
select pg_temp.check('none policy no issuance','POLICY',not exists(select 1 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='disabled'));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support')));reset role;
select pg_temp.check('activation no retroactive disabled source credit','POLICY',boss_private.bucks_issue((select id from public.fundraising_success_evidence where source_reference='disabled'))is null);
-- Read-only canonical charge integration. No allocation/payment insertion.
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)select pg_temp.f('org'),id,'active','{"fees":true}'::jsonb,now()-interval'1 day'from public.modules where key='registration';
insert into public.registration_offerings(id,organization_id,title,scope_type,scope_id,created_by_person_id,updated_by_person_id)
 values(pg_temp.f('offering'),pg_temp.f('org'),'Synthetic fee preview','organization',pg_temp.f('org'),pg_temp.f('admin'),pg_temp.f('admin'));
insert into public.registrations(id,organization_id,offering_id,participant_id,household_id,submitted_by_person_id,offering_snapshot,participant_snapshot)
 values(pg_temp.f('registration'),pg_temp.f('org'),pg_temp.f('offering'),pg_temp.f('participant-child1'),pg_temp.f('household'),pg_temp.f('parent'),'{}','{}');
insert into public.charges(id,organization_id,registration_id,participant_id,household_id,title,charge_type,original_amount_minor,currency,created_by_person_id)
 values(pg_temp.f('charge'),pg_temp.f('org'),pg_temp.f('registration'),pg_temp.f('participant-child1'),pg_temp.f('household'),'Synthetic camp obligation','camp',5000,'USD',pg_temp.f('admin'));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('preview uses smaller due/same-org available','PREVIEW',public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w(),'charge_id',pg_temp.f('charge')))->'charges'->0->>'eligible_minor'='1000');
select pg_temp.check('preview remaining tender exact','PREVIEW',public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w(),'charge_id',pg_temp.f('charge')))->'charges'->0->>'remaining_minor'='4000');
select pg_temp.check('API minor amounts are decimal strings','PRECISION',jsonb_typeof(public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w()))->'wallets'->0->'available_minor')='string');
reset role;
select pg_temp.check('preview never changes charge/payment/ledger','PREVIEW',(boss_private.registration_charge_balance(pg_temp.f('charge'))->>'balance_due_minor')::bigint=5000 and(select count(*)=0 from public.payment_allocations)and boss_private.bucks_available(pg_temp.w())=1000);
update public.guardian_relationships set can_manage_payments=false where id=pg_temp.f('guardian-child1');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('wallet flag does not grant payment authority',format('select public.boss_bucks_read(%L::jsonb)',jsonb_build_object('wallet_id',pg_temp.w(),'charge_id',pg_temp.f('charge'))));
select pg_temp.denied('forged charge ID denied',format('select public.boss_bucks_read(%L::jsonb)',jsonb_build_object('wallet_id',pg_temp.w(),'charge_id',pg_temp.f('missing'))));reset role;
-- Notifications retain current guardian + communication + explicit wallet access.
select pg_temp.check('earned notification deduplication','NOTIFY',(select count(*)=2 from public.notification_events where source_type='boss_bucks_history'and event_type='boss_bucks.earned'));
select boss_private.notification_process(pg_temp.f('org'),100);
select pg_temp.check('guardian receives safe wallet notification','NOTIFY',exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where n.recipient_person_id=pg_temp.f('parent')and e.source_type='boss_bucks_history'));
select pg_temp.check('household-only no receipt','NOTIFY',not exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where n.recipient_person_id=pg_temp.f('household-only')and e.source_type='boss_bucks_history'));
update public.guardian_relationships set can_manage_boss_bucks=false where id=pg_temp.f('guardian-child1');
select pg_temp.check('notification revocation effective now','NOTIFY',not exists(select 1 from public.notification_events e where source_type='boss_bucks_history'and boss_private.notification_source_visible(e,pg_temp.f('parent'))));
select count(*)passed_assertions,'Phase 7B policy/preview' suite from phase5a_assertions;rollback;
