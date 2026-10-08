-- Disposable synthetic merchants; reuses real Phase 7E issuance operations.
\ir ../phase7e/fixture.sql
create temp table merchant_test_results(label text primary key,result jsonb);
grant all on merchant_test_results to authenticated;
grant select on merchant_test_results to anon;
create function pg_temp.mm(label text,action text,input jsonb)returns jsonb language plpgsql as $$declare r jsonb;begin
 r:=public.boss_merchants_mutate(jsonb_build_object('request_id',pg_temp.f('merchant-request-'||label),'action',action,'input',input));
 insert into merchant_test_results values(label,r)on conflict on constraint merchant_test_results_pkey do update set result=excluded.result;return r;end$$;
create function pg_temp.mid(label text,key text default 'resource_id')returns uuid language sql stable as $$select(result->>key)::uuid from merchant_test_results where merchant_test_results.label=mid.label$$;
create function pg_temp.mr(label text)returns jsonb language sql stable as $$select result from merchant_test_results where merchant_test_results.label=mr.label$$;
create function pg_temp.mi(extra jsonb default '{}')returns jsonb language sql stable as $$select jsonb_build_object('merchant_id',pg_temp.mid('merchant','merchant_id'))||extra$$;
create function pg_temp.mo(label text,extra jsonb default '{}')returns jsonb language plpgsql as $$begin
 return pg_temp.mm(label,'offer.create',pg_temp.mi(jsonb_build_object('family_id',pg_temp.mid('family'),'title','Synthetic 10 percent','offer_type','percentage_off','discount_bps',1000,
 'qualification','none','stacking','none','starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'10 days',
 'location_policy','selected','location_ids',jsonb_build_array(pg_temp.mid('loc-a')))||extra));end$$;
create function pg_temp.proof(label text)returns text language sql immutable as $$select encode(sha256(convert_to('INERT DISPOSABLE BUSINESS PROOF '||label,'UTF8')),'hex')$$;
grant execute on function pg_temp.mm(text,text,jsonb),pg_temp.mid(text,text),pg_temp.mr(text),pg_temp.mi(jsonb),pg_temp.mo(text,jsonb),pg_temp.proof(text)to authenticated,anon;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.mm('market','market.create','{"country":"US","region":"VA","market":"SYNTHETIC LOCAL MARKET"}');
select pg_temp.mm('market-ca','market.create','{"country":"CA","region":"ON","market":"SYNTHETIC CANADIAN MARKET"}');
select pg_temp.mm('market-other','market.create','{"country":"US","region":"NC","market":"SYNTHETIC OTHER MARKET"}');
select pg_temp.mm('merchant','merchant.create',jsonb_build_object('market_id',pg_temp.mid('market','market_id'),'name','SYNTHETIC merchant','category','restaurants','controlled',true));
select pg_temp.mm('merchant-other','merchant.create',jsonb_build_object('market_id',pg_temp.mid('market','market_id'),'name','SYNTHETIC other merchant','category','retail','controlled',true));
select pg_temp.actor('parent');
select pg_temp.mm('claim','claim.submit',pg_temp.mi('{"statement":"Synthetic independently reviewed ownership claim"}'));
select pg_temp.actor('admin');
select pg_temp.mm('approve-claim','claim.review',pg_temp.mi(jsonb_build_object('claim_id',pg_temp.mid('claim'),'state','approved','reason','Reviewed synthetic ownership evidence')));
select pg_temp.mm('configure','merchant.configure',pg_temp.mi('{"status":"active","portal":true,"offers":true,"redemption":true}'));
select pg_temp.mm('approve','merchant.review',pg_temp.mi('{"state":"active","reason":"Reviewed synthetic listing approval"}'));
select pg_temp.mm('loc-a','location.create',pg_temp.mi(jsonb_build_object('market_id',pg_temp.mid('market','market_id'),'name','SYNTHETIC Location A','address','1 Synthetic Street','city','Synthetic City','postal_code','00000','timezone','America/New_York')));
select pg_temp.mm('loc-b','location.create',pg_temp.mi(jsonb_build_object('market_id',pg_temp.mid('market','market_id'),'name','SYNTHETIC Location B','address','2 Synthetic Street','city','Synthetic City','postal_code','00000','timezone','America/New_York')));
select pg_temp.mm('loc-ca','location.create',pg_temp.mi(jsonb_build_object('market_id',pg_temp.mid('market-ca','market_id'),'name','SYNTHETIC Canada','address','3 Synthetic Street','city','Synthetic City','postal_code','X0X0X0','timezone','America/Toronto')));
select pg_temp.mm('loc-other','location.create',pg_temp.mi(jsonb_build_object('market_id',pg_temp.mid('market-other','market_id'),'name','SYNTHETIC Other State','address','4 Synthetic Street','city','Synthetic City','postal_code','00000','timezone','America/New_York')));
select pg_temp.mm('manager','access.grant',pg_temp.mi(jsonb_build_object('person_id',pg_temp.f('coach'),'role','location_manager','location_id',pg_temp.mid('loc-a'))));
select pg_temp.mm('clerk','access.grant',pg_temp.mi(jsonb_build_object('person_id',pg_temp.f('staff'),'role','redemption_clerk','location_id',pg_temp.mid('loc-a'))));
select pg_temp.mm('clerk2','access.grant',pg_temp.mi(jsonb_build_object('person_id',pg_temp.f('assistant'),'role','redemption_clerk','location_id',pg_temp.mid('loc-a'))));
select pg_temp.mm('editor','access.grant',pg_temp.mi(jsonb_build_object('person_id',pg_temp.f('scorer'),'role','offer_editor','location_id',pg_temp.mid('loc-a'))));
select pg_temp.mm('family','family.create',pg_temp.mi('{"usage_limit":2,"reset_period":"lifetime","usage_timezone":"America/New_York"}'));
select pg_temp.mo('offer');
select pg_temp.mm('submit','offer.status',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('offer'),'state','pending_review')));
select pg_temp.mm('publish','offer.status',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('offer'),'state','published','reason','Reviewed synthetic structured offer')));
select pg_temp.actor('parent');
select pg_temp.dm('member-trial','trial.start',jsonb_build_object('revision_id',pg_temp.did('base30','revision_id'),'path',pg_temp.fpath('share')));
reset role;
