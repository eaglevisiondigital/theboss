\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir global/fixture.sql
do $$declare channels text[];k int;n int:=16;label text;expected boolean;begin
 for k in 1..4 loop
  channels:=case k when 1 then array['money_board']when 2 then array['direct_support']when 3 then array['money_board','direct_support']else array['money_board','direct_support']end;
  set local role authenticated;perform pg_temp.actor('admin');
  perform pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode',case when k=4 then'none'else'percentage'end,'basis_points',case when k=4 then 0 else 5000 end,'currency','USD','channels',to_jsonb(channels)));
  reset role;
  label:='channel-group-'||k;perform pg_temp.group_checkout(label,'card',array[n,n+1]);perform boss_private.rails_dispatch(pg_temp.f('checkout-'||label));perform pg_temp.receive(label,'captured');
  expected:=k<>4 and 'money_board'=any(channels);
  perform pg_temp.check('group channel matrix '||k,'CHANNEL',(select count(*)=case when expected then 1 else 0 end from public.boss_bucks_grants where evidence_id=pg_temp.group_evidence(label)));
  label:='channel-legacy-'||k;perform pg_temp.checkout(label,'card',n+2);perform boss_private.rails_dispatch(pg_temp.f('checkout-'||label));perform pg_temp.receive(label,'captured');
  perform pg_temp.check('legacy tile channel matrix '||k,'CHANNEL',(select count(*)=case when expected then 1 else 0 end from public.boss_bucks_grants where intent_id=(select intent_id from public.payment_checkouts where id=pg_temp.f('checkout-'||label))));
  label:='channel-direct-'||k;perform pg_temp.checkout(label);perform boss_private.rails_dispatch(pg_temp.f('checkout-'||label));perform pg_temp.receive(label,'captured');expected:=k<>4 and 'direct_support'=any(channels);
  perform pg_temp.check('direct donation channel matrix '||k,'CHANNEL',(select count(*)=case when expected then 1 else 0 end from public.boss_bucks_grants where intent_id=(select intent_id from public.payment_checkouts where id=pg_temp.f('checkout-'||label))));
  n:=n+3;
 end loop;
end$$;
select pg_temp.receive('channel-group-1','captured');
select pg_temp.check('channel replay never repeats Wallet earning','REPLAY',(select count(*)=1 from public.boss_bucks_grants where evidence_id=pg_temp.group_evidence('channel-group-1')));
select pg_temp.refund_group('channel-group-1',3300);
select pg_temp.check('refunded grouped Wallet source recovers once','CORRECTION',(select entitlement_minor=0 from public.boss_bucks_source_corrections where grant_id=(select id from public.boss_bucks_grants where evidence_id=pg_temp.group_evidence('channel-group-1'))order by created_at desc,id desc limit 1));
select pg_temp.check('unknown canonical source fails closed','FORGERY',boss_private.fundraising_channel(gen_random_uuid())is null);
select pg_temp.check('grouped identity is canonical despite null legacy board','LINEAGE',(select board_id is null and boss_private.fundraising_channel(id)='money_board'from public.fundraising_intents where id=(select intent_id from public.payment_checkouts where id=pg_temp.f('checkout-channel-group-1'))));
select pg_temp.check('direct source stays separate from grouped source','LINEAGE',(select boss_private.fundraising_channel(id)='direct_support'from public.fundraising_intents where id=(select intent_id from public.payment_checkouts where id=pg_temp.f('checkout-channel-direct-1'))));
set local role authenticated;select pg_temp.actor('other-admin');
select pg_temp.denied('other tenant cannot bind Wallet channel',format('select pg_temp.am(''wallet_channel.bind'',%L)',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'channel','money_board','wallet_policy_id',gen_random_uuid(),'starts_at',clock_timestamp())));
reset role;set constraints all immediate;
select count(*)passed_assertions,'Global Wallet channel matrix' suite from phase5a_assertions;rollback;
