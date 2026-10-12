\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
grant all on discount_test_results to anon;
create function pg_temp.guest_trial(label text)returns void language plpgsql as $$begin
 insert into discount_test_results values(label,public.boss_discounts_support(jsonb_build_object('action','trial.start','request_id',pg_temp.f(label),'input',jsonb_build_object('path',pg_temp.fpath('share'),'revision_id',pg_temp.did('base30','revision_id'),'display_name','SYNTHETIC private supporter'))));end$$;
grant execute on function pg_temp.guest_trial(text)to anon;
set local role anon;select pg_temp.guest_trial('guest-trial');reset role;
select pg_temp.check('guest trial is pending, not protected access','CLAIM',exists(select 1 from public.discount_memberships where subject_id is null and state='pending_claim')and not exists(select 1 from public.entitlements where source_type='discount_member_source'));
select pg_temp.check('public trial reveals no canonical person or household','PRIVACY',not(pg_temp.dr('guest-trial')?|array['membership_id','donor_id','person_id','household_id']));
set local role anon;
insert into discount_test_results values('trial-donation',public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',pg_temp.f('trial-donation'),'input',jsonb_build_object('path',pg_temp.fpath('share'),'display_name','SYNTHETIC anonymous supporter','anonymous',true,'amount_minor',2501,'capability',repeat('e',64),'trial_capability',pg_temp.dr('guest-trial')->>'claim_secret'))));
reset role;
select pg_temp.check('trial and support retain exact canonical donor','LINEAGE',exists(select 1 from public.fundraising_intents i join boss_private.discount_trial_flows f on f.intent_id=i.id where i.request_id=pg_temp.f('trial-donation')and i.donor_id=f.donor_id));
select boss_private.fundraising_ingest_success(id,'disposable-test','trial-donation',2501,'USD',clock_timestamp())from public.fundraising_intents where request_id=pg_temp.f('trial-donation');
select pg_temp.check('trusted 2501 success creates gift beside original trial','GIFT',exists(select 1 from public.discount_member_sources t join public.discount_member_sources g on g.membership_id=t.membership_id where t.kind='fundraising_trial'and g.kind='supporter_gift'and g.starts_at>t.starts_at));
select pg_temp.check('anonymous supporter privately receives gift lineage','PRIVACY',exists(select 1 from public.fundraising_intents i join public.discount_member_sources g on g.intent_id=i.id and g.kind='supporter_gift'where i.request_id=pg_temp.f('trial-donation')and i.anonymous));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.dm('guest-claim','membership.claim',jsonb_build_object('claim_secret',pg_temp.dr('guest-trial')->>'claim_secret'));
select pg_temp.check('claimed gift is active in native consumer projection','CLAIM',(public.boss_discounts_read(jsonb_build_object('membership_id',pg_temp.did('guest-claim')))->'memberships'->0->'effective'->>'source')='supporter_gift');
select pg_temp.actor('household-only');
select pg_temp.denied('claim replay by another account denied',format('select pg_temp.dm(''stolen-replay'',''membership.claim'',%L)',jsonb_build_object('claim_secret',pg_temp.dr('guest-trial')->>'claim_secret')),'PT404');
reset role;
select pg_temp.success('threshold-25',2500);
select pg_temp.check('exactly 25 never issues gift','THRESHOLD',not exists(select 1 from public.discount_member_sources s join public.fundraising_intents i on i.id=s.intent_id where i.request_id=pg_temp.f('request-threshold-25')));
select pg_temp.check('gift source term is explicit immutable revision','TERM',exists(select 1 from public.discount_member_sources s join public.discount_product_revisions r on r.id=s.revision_id where s.kind='supporter_gift'and s.ends_at=s.starts_at+make_interval(days=>r.term_days)and r.term_days=120));
insert into public.fundraising_intent_events(intent_id,state,source_reference,amount_minor,remaining_valid_amount_minor)select id,'partially_refunded','SYNTHETIC threshold reversal',1,2500 from public.fundraising_intents where request_id=pg_temp.f('trial-donation');
select pg_temp.check('gift reversal falls back to original still valid trial','REVERSAL',(boss_private.discount_effective(pg_temp.did('guest-claim'))->>'source')='fundraising_trial');
select pg_temp.check('gift source is revoked, retained in history','HISTORY',exists(select 1 from public.discount_member_sources s join public.discount_source_revocations v on v.source_id=s.id where s.membership_id=pg_temp.did('guest-claim')and s.kind='supporter_gift'and v.reason='gift_reversal'));
select pg_temp.check('claim secret never stored in receipts or audit','PRIVACY',not exists(select 1 from boss_private.discount_requests where result::text like'%'||(pg_temp.dr('guest-trial')->>'claim_secret')||'%')and not exists(select 1 from public.discount_membership_history where details::text like'%'||(pg_temp.dr('guest-trial')->>'claim_secret')||'%'));
update public.organization_modules set configuration=configuration||'{"discount_membership":false}'::jsonb where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='boss_bucks');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('claim receipt cannot retain authority when module disabled',format('select pg_temp.dm(''guest-claim'',''membership.claim'',%L)',jsonb_build_object('claim_secret',pg_temp.dr('guest-trial')->>'claim_secret')));
reset role;
select pg_temp.check('source truth prevents stale entitlement after module disabled','ENTITLEMENT',not boss_private.has_active_entitlement('person',pg_temp.f('parent'),'product','boss_bucks.discounts:'||(select id::text from public.discount_member_sources where membership_id=pg_temp.did('guest-claim')and kind='fundraising_trial')));
set constraints all immediate;
select count(*)passed_assertions,'Phase 7E trials gifts and secure claims'::text suite from phase5a_assertions;rollback;
