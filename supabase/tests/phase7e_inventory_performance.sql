\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dm('scale1','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC scale 1','quantity',1000,'controlled',true));
select pg_temp.dm('scale2','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC scale 2','quantity',1000,'controlled',true));
select pg_temp.dm('scale3','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC scale 3','quantity',1000,'controlled',true));
select pg_temp.dm('scale4','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC scale 4','quantity',1000,'controlled',true));
select pg_temp.dm('scale5','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC scale 5','quantity',1000,'controlled',true));
select pg_temp.dm('scale6','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC scale 6','quantity',1000,'controlled',true));
reset role;
analyze public.discount_physical_cards;analyze boss_private.discount_card_secrets;
select pg_temp.check('6000 identities beyond 500 are unique','SCALE',(select count(*)=6000 and count(distinct serial)=6000 from public.discount_physical_cards));
select pg_temp.check('each card has one private digest and creation history','SCALE',(select count(*)=6000 from boss_private.discount_card_secrets)and(select count(*)=6000 from public.discount_card_history where action='created'));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('inventory projection is bounded at scale','BOUNDED',jsonb_array_length(public.boss_discounts_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'cards')=100);
select pg_temp.check('inventory never returns activation secrets','PRIVACY',public.boss_discounts_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))::text not like'%activation_secret%');
select pg_temp.denied('bulk operation above 1000 denied',format('select pg_temp.dm(''above-bound'',''batch.create'',%L)',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC above bound','quantity',1001,'controlled',true)),'PT422');
reset role;
do $$declare plan jsonb;serial text;digest text;begin
 select c.serial,s.digest into serial,digest from public.discount_physical_cards c join boss_private.discount_card_secrets s on s.card_id=c.id order by c.id limit 1;
 execute format('explain(format json)select id from public.discount_physical_cards where serial=%L',serial)into plan;
 perform pg_temp.check('serial lookup uses unique index at scale','INDEX',plan::text like'%Index Scan%');
 execute format('explain(format json)select card_id from boss_private.discount_card_secrets where digest=%L',digest)into plan;
 perform pg_temp.check('secret digest lookup uses unique index at scale','INDEX',plan::text like'%Index Scan%');
 execute format('explain(format json)select id from public.discount_physical_cards where organization_id=%L order by id desc limit 100',pg_temp.f('org'))into plan;
 perform pg_temp.check('bounded organization read uses index at scale','INDEX',plan::text like'%Index%');
end$$;
select pg_temp.denied('card serial history cannot be deleted','delete from public.discount_physical_cards','23514');
set constraints all immediate;
select count(*)passed_assertions,'Phase 7E 6000-card bounded performance'::text suite from phase5a_assertions;rollback;
