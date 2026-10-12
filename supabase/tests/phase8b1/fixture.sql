-- Synthetic disposable fixture only. Original identity/membership/native offers reused.
\ir ../phase8a/fixture.sql
insert into public.role_assignments(person_id,role_id,scope_type)select pg_temp.f('coach'),id,'platform'from public.roles where key='platform_administrator';
create temp table partner_results(label text primary key,result jsonb);grant all on partner_results to authenticated;grant select on partner_results to anon;
create function pg_temp.pm(label text,action text,i jsonb)returns jsonb language plpgsql as $$declare r jsonb;begin
 r:=public.boss_partners_mutate(jsonb_build_object('request_id',pg_temp.f('partner-request-'||label),'action',action,'input',i));
 insert into partner_results values(label,r)on conflict on constraint partner_results_pkey do update set result=excluded.result;return r;end$$;
create function pg_temp.pid(label text)returns uuid language sql stable as $$select(result->>'resource_id')::uuid from partner_results where partner_results.label=pid.label$$;
create function pg_temp.pi(extra jsonb default '{}')returns jsonb language sql stable as $$select jsonb_build_object('provider_id',pg_temp.pid('provider'))||extra$$;
create function pg_temp.item(external text default 'benefit-1',revision int default 1,extra jsonb default '{}')returns jsonb language sql stable as $$select jsonb_build_object('external_id',external,'source_revision',revision,'contract_id',pg_temp.pid('contract'),
 'category','restaurants','title','Synthetic partner dining','public_description','Synthetic catalog description','member_terms','Synthetic private ten percent terms','country','US','region','VA','market_id',pg_temp.mid('market','market_id'),
 'product_id',pg_temp.did('digital','product_id'),'minimum_tier','local','fulfillment','percentage_discount','starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'10 days')||extra$$;
create function pg_temp.feed(label text,seq int,kind text,items jsonb)returns jsonb language sql volatile as $$select pg_temp.pm(label,'catalog.import',pg_temp.pi(jsonb_build_object('feed_sequence',seq,'kind',kind,'synthetic',true,'items',items)))$$;
grant execute on function pg_temp.pm(text,text,jsonb),pg_temp.pid(text),pg_temp.pi(jsonb),pg_temp.item(text,int,jsonb),pg_temp.feed(text,int,text,jsonb)to authenticated,anon;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.pm('provider','provider.create','{"key":"synthetic-partner-a","name":"Synthetic partner A","synthetic":true}');
select pg_temp.pm('provider-b','provider.create','{"key":"synthetic-partner-b","name":"Synthetic partner B","synthetic":true}');
select pg_temp.pm('configuration','configuration.create',pg_temp.pi(jsonb_build_object('method','mock','capabilities',jsonb_build_array('catalog_read','benefit_detail'),'max_stale_seconds',86400,'full_withdraw_missing',true,'starts_at',clock_timestamp()-interval'1 day')));
select pg_temp.pm('contract','contract.create',pg_temp.pi(jsonb_build_object('document_reference','legal-reference/synthetic-test','rights_holder_reference','Synthetic rights holder','countries',jsonb_build_array('US'),'categories',jsonb_build_array('restaurants','travel','gift_cards'),
 'methods',jsonb_build_array('mock'),'product_id',pg_temp.did('digital','product_id'),'minimum_tier','local','display_rights',true,'caching_rights',true,'branding_rules','Synthetic reviewed branding','attribution_rules','Synthetic explicit attribution','sharing_fields','[]'::jsonb,'retention_days',0,'refund_policy_reference','Synthetic refund evidence policy','starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'20 days')));
select pg_temp.actor('coach');select pg_temp.pm('approve-contract','contract.review',pg_temp.pi(jsonb_build_object('contract_id',pg_temp.pid('contract'),'state','approved','approval_reference','Synthetic independent legal approval')));
select pg_temp.actor('admin');
select pg_temp.pm('territory','territory.create',pg_temp.pi(jsonb_build_object('contract_id',pg_temp.pid('contract'),'country','US','region','VA','market_id',pg_temp.mid('market','market_id'),'starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'10 days')));
select pg_temp.pm('evaluation','provider.state',pg_temp.pi('{"expected_version":1,"state":"evaluation","reason":"Synthetic evaluation review"}'));
select pg_temp.pm('pending','provider.state',pg_temp.pi('{"expected_version":2,"state":"contract_pending","reason":"Synthetic contract review"}'));
select pg_temp.pm('approved','provider.state',pg_temp.pi('{"expected_version":3,"state":"approved","reason":"Synthetic legal approval"}'));
select pg_temp.pm('configured','provider.state',pg_temp.pi('{"expected_version":4,"state":"configured","reason":"Synthetic technical review"}'));
reset role;create temp table partner_payloads(label text primary key,item jsonb);grant all on partner_payloads to authenticated;insert into partner_payloads values('original',pg_temp.item());set local role authenticated;
select pg_temp.feed('feed',1,'delta',(select jsonb_build_array(item)from partner_payloads where label='original'));
reset role;
insert into partner_results select 'benefit',jsonb_build_object('resource_id',id)from public.partner_benefit_revisions where provider_id=pg_temp.pid('provider');
insert into partner_results select 'source',jsonb_build_object('resource_id',source_id)from public.partner_benefit_revisions where provider_id=pg_temp.pid('provider');
set local role authenticated;select pg_temp.pm('review-benefit','catalog.review',pg_temp.pi(jsonb_build_object('revision_id',pg_temp.pid('benefit'),'state','reviewed')));
reset role;
