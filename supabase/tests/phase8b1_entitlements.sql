\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8b1/fixture.sql
select pg_temp.check('household membership alone is not personal entitlement','PRIVACY',not(boss_private.partner_decision(pg_temp.f('household-only'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'membership_eligible')::boolean);
select pg_temp.check('US membership is not Canadian entitlement','COUNTRY',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market-ca','market_id'))->>'membership_eligible')::boolean);
select pg_temp.check('local membership cannot cover other state','REGION',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market-other','market_id'))->>'membership_eligible')::boolean);
-- A second source is issued through the original native Phase 7E commands.
-- Its broader tier must neither authorize this exact product nor mask its valid
-- narrower source during selection.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dm('partner-other-product','product.create','{"code":"synthetic_partner_other","name":"Synthetic other membership product","kind":"digital"}');
select pg_temp.revision('partner-other-revision','partner-other-product',jsonb_build_object('membership_product_id',pg_temp.did('partner-other-product','product_id'),'tier','nationwide'));
select pg_temp.dm('partner-other-binding','campaign.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'revision_id',pg_temp.did('partner-other-revision','revision_id'),'trial_enabled',true,'gift_enabled',false,'sale_enabled',false));
select pg_temp.actor('parent');
select pg_temp.dm('partner-other-trial','trial.start',jsonb_build_object('revision_id',pg_temp.did('partner-other-revision','revision_id'),'path',pg_temp.fpath('share')));reset role;
select pg_temp.check('both independently valid product sources exist','PRODUCT',(select count(distinct dm.product_id)=2 from public.discount_memberships dm join public.discount_member_sources ds on ds.membership_id=dm.id where dm.subject_id=pg_temp.f('parent')and boss_private.discount_source_valid(ds.id)));
select pg_temp.check('other higher-tier product does not mask valid original source','PRODUCT',(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'membership_eligible')::boolean);
select pg_temp.check('exact product source selected','PRODUCT',exists(select 1 from public.discount_member_sources ds join public.discount_memberships dm on dm.id=ds.membership_id where ds.id=boss_private.partner_membership_source(pg_temp.f('parent'),pg_temp.did('digital','product_id'),pg_temp.mid('market','market_id'),'local')and dm.product_id=pg_temp.did('digital','product_id')and ds.tier='local'));
savepoint status_probe;
update public.people set status='inactive'where id=pg_temp.f('parent');
select pg_temp.check('inactive canonical person denied membership use','CURRENT',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'membership_eligible')::boolean);
rollback to savepoint status_probe;
savepoint module_probe;
update public.modules set status='inactive'where key='commerce';
set local role authenticated;select pg_temp.actor('admin');select pg_temp.denied('inactive module denies signed provider read','select public.boss_partners_read()');reset role;
rollback to savepoint module_probe;
insert into partner_payloads values('revoke-input',jsonb_build_object('source_id',(select id from public.discount_member_sources where membership_id=pg_temp.did('member-trial'))));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dm('partner-revoke-original','source.revoke',(select item from partner_payloads where label='revoke-input'));reset role;
select pg_temp.check('revoked original source denied despite other active product','PRODUCT',not(boss_private.partner_decision(pg_temp.f('parent'),pg_temp.pid('benefit'),pg_temp.mid('market','market_id'))->>'membership_eligible')::boolean);
select pg_temp.check('no export authority from membership','SHARING',(select sharing_fields='{}'from public.partner_contract_revisions where id=pg_temp.pid('contract')));
select pg_temp.check('no provider operational after eligibility probes','ACTIVATION',not exists(select 1 from public.partner_config_revisions where operational or credentials_ready));
set constraints all immediate;
select count(*)passed_assertions,'Phase 8B1 exact product/geography/current entitlement'::text suite from phase5a_assertions;rollback;
