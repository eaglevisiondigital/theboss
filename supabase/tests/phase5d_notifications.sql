-- Low-frequency halftime reuses the shared bounded in-app worker only.
begin;
\ir phase5d/fixture.sql
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
 select pg_temp.f('org'),id,'active','{"communications":true,"in_app_notifications":true,"guardian_visibility":true,"email_notifications":false}',now()-interval '3 days' from public.modules where key='messaging';
update public.guardian_relationships set can_receive_communications=true where id=pg_temp.f('guardian-child1');
set local role authenticated;
select pg_temp.actor('admin');select pg_temp.ff_create('halftime');
select pg_temp.ff_play('halftime','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('halftime','primary',1),'yards',1));
select pg_temp.ff_end('halftime');select pg_temp.ff_op('football.period.start','halftime');
select pg_temp.ff_clock('halftime',0);select pg_temp.ff_op('football.period.end','halftime','{}','halftime-end');
select pg_temp.check('halftime command retry is caller-bound replay','REPLAY',
 (public.boss_games_mutate(pg_temp.f('halftime-end'),pg_temp.game_command('football.period.end','halftime','{}',(select version-1 from phase5a_games where label='halftime')))->>'replayed')::boolean);
reset role;
select pg_temp.check('one Q2 boundary source despite retry','SOURCE',
 (select count(*)=1 from public.notification_events e join public.game_operations o on o.id=e.source_id where o.game_id=pg_temp.ff_game('halftime') and e.event_type='game.halftime'));
select pg_temp.check('no ordinary Football play notification','SOURCE',
 not exists(select 1 from public.notification_events e join public.game_operations o on o.id=e.source_id where o.game_id=pg_temp.ff_game('halftime') and o.operation like 'football.%' and o.operation<>'football.period.end'));
select pg_temp.check('halftime safe source omits roster score and play attribution','PRIVACY',
 not exists(select 1 from public.notification_events e join public.game_operations o on o.id=e.source_id cross join lateral jsonb_object_keys(e.safe_data)k where o.game_id=pg_temp.ff_game('halftime') and k not in('team_id','source_version')));
set local role authenticated;select pg_temp.actor('admin');
select public.boss_notifications_mutate(pg_temp.f('halftime-worker-one'),pg_temp.cmd('delivery.process',jsonb_build_object('organization_id',pg_temp.f('org'),'limit',100)));
select public.boss_notifications_mutate(pg_temp.f('halftime-worker-two'),pg_temp.cmd('delivery.process',jsonb_build_object('organization_id',pg_temp.f('org'),'limit',100)));
reset role;
select pg_temp.check('authorized guardian receives halftime in-app','GUARDIAN',
 exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id join public.notification_deliveries d on d.notification_id=n.id where n.recipient_person_id=pg_temp.f('parent') and e.event_type='game.halftime' and d.channel='in_app' and d.status='sent'));
select pg_temp.check('worker replay retains recipient deduplication','DELIVERY',
 not exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.event_type='game.halftime' group by notification_event_id,recipient_person_id having count(*)>1));
select pg_temp.check('household-only person receives no halftime','GUARDIAN',
 not exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.event_type='game.halftime' and n.recipient_person_id=pg_temp.f('household-only')));
select pg_temp.check('halftime activates no external transport','PROVIDER',
 not exists(select 1 from public.notification_deliveries d join public.notifications n on n.id=d.notification_id join public.notification_events e on e.id=n.notification_event_id where e.event_type='game.halftime' and d.channel<>'in_app' and d.status in('queued','processing','sent','delivered')));
select count(*) as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
