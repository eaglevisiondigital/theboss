\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7a/fixture.sql
select pg_temp.check('launch and enrollment queued only once','NOTIFY',(select count(*)=2 from public.notification_events where organization_id=pg_temp.f('org')and source_type='fundraising_history'));
select boss_private.notification_process(pg_temp.f('org'),100);
select pg_temp.check('authorized guardian receives fundraising','NOTIFY',(select count(*)>=1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.source_type='fundraising_history'and n.recipient_person_id=pg_temp.f('parent')));
select pg_temp.check('household alone not fundraising recipient','NOTIFY',not exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.source_type='fundraising_history'and n.recipient_person_id=pg_temp.f('household-only')));
select boss_private.notification_process(pg_temp.f('org'),100);
select pg_temp.check('recipient deduplication','NOTIFY',not exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.source_type='fundraising_history'group by n.notification_event_id,n.recipient_person_id having count(*)>1));
select pg_temp.check('safe no donor details in notification','NOTIFY',not exists(select 1 from public.notification_events where source_type='fundraising_history'and safe_data::text~'(email|mobile|donor|session|token)'));
update public.guardian_relationships set can_manage_fundraising=false where id=pg_temp.f('guardian-child1');
select pg_temp.check('notification current revocation gate','NOTIFY',not exists(select 1 from public.notification_events e where e.source_type='fundraising_history'and boss_private.notification_source_visible(e,pg_temp.f('parent'))));
update public.guardian_relationships set can_manage_fundraising=true,can_receive_communications=false where id=pg_temp.f('guardian-child1');
select pg_temp.check('fundraising capability does not grant communication receipt','NOTIFY',not exists(select 1 from public.notification_events e cross join lateral boss_private.notification_candidates(e,null,200)candidate where e.source_type='fundraising_history'and candidate.person_id=pg_temp.f('parent')));
select pg_temp.check('existing guardian receipt closes when communications capability ends','NOTIFY',not exists(select 1 from public.notification_events e where e.source_type='fundraising_history'and boss_private.notification_source_visible(e,pg_temp.f('parent'))));
select count(*)passed_assertions from pg_temp.phase5a_assertions;rollback;
