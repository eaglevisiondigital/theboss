\ir ../grouped/fixture.sql
-- The platform reviewer is an existing synthetic actor in this disposable database.
insert into public.role_assignments(person_id,role_id,scope_type,starts_at)
select pg_temp.f('director'),id,'platform',clock_timestamp()-interval'1 day'from public.roles where key='platform_administrator';
create function pg_temp.am(a text,i jsonb,label text default null,r uuid default gen_random_uuid())returns jsonb language plpgsql as $$
declare result jsonb;begin
 result:=public.boss_fundraising_allocation_mutate(jsonb_build_object('action',a,'request_id',r,'input',i));
 if label is not null then insert into group_results values(label,result)on conflict on constraint group_results_pkey do update set data=excluded.data;end if;
 return result;
end$$;
grant execute on function pg_temp.am(text,jsonb,text,uuid)to authenticated,anon;
create function pg_temp.policy(channel text default 'money_board',team uuid default null,unit uuid default null,weights int[]default array[2000,3000,5000])returns uuid language plpgsql as $$
declare id uuid;begin
 set local role authenticated;perform pg_temp.actor('director');
 id:=(pg_temp.am('platform_policy.create',jsonb_build_object('organization_id',pg_temp.f('org'),'campaign_id',pg_temp.fid('campaign'),'channel',channel,'currency','USD','settlement_policy_id',pg_temp.f('settlement-policy'),'agreement_reference','LOCAL-SYNTHETIC-AGREEMENT','participant_credit_max_bps',10000,'wallet_permitted',true,'starts_at',clock_timestamp()-interval'1 day'))->>'id')::uuid;
 perform pg_temp.actor('admin');
 id:=(pg_temp.am('allocation_policy.create',jsonb_strip_nulls(jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'platform_policy_id',id,'channel',channel,'team_id',team,'unit_id',unit,'organization_bps',weights[1],'destination_bps',weights[2],'participant_bps',weights[3],'starts_at',clock_timestamp()-interval'1 hour')))->>'id')::uuid;
 reset role;return id;
end$$;
create function pg_temp.settle(label text,fee bigint default 0)returns uuid language plpgsql as $$
declare c public.payment_checkouts;event uuid;payment uuid;begin
 select *into c from public.payment_checkouts where id=pg_temp.f('checkout-'||label);
 if not exists(select 1 from public.provider_event_evidence where event_reference=label||'-settlement')then perform boss_private.rails_receive(c.id,label||'-settlement','settled','LOCAL-TRANSACTION-'||label,c.external_minor,c.currency,clock_timestamp(),repeat('e',64),jsonb_build_object('processor_fee_minor',fee));end if;
 select id into event from public.provider_event_evidence where event_reference=label||'-settlement';
 select payment_id into payment from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null;
 perform boss_private.rails_settlement_match(payment,event,fee);return payment;
end$$;
