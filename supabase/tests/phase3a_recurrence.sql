-- Phase 3A pure recurrence and durable-exception acceptance. Synthetic only.
-- Everything, including temporary helpers, is removed by ROLLBACK.
\o /dev/null
begin;
create temp table phase3a_recurrence_assertions(label text primary key,category text not null) on commit drop;
create function pg_temp.calendar_assert(p_label text,p_category text,p_actual boolean) returns void
language plpgsql security invoker set search_path=pg_catalog,pg_temp as $$
begin
 if p_actual is distinct from true then raise exception 'FAIL [%] %',p_category,p_label;end if;
 insert into pg_temp.phase3a_recurrence_assertions values(p_label,p_category);
end;
$$;
create function pg_temp.calendar_id(p_label text) returns uuid language sql immutable security invoker set search_path='' as $$select md5('boss-phase3a-recurrence-fixture:'||p_label)::uuid$$;
create function pg_temp.calendar_count(p_label text,p_start timestamptz,p_end timestamptz,p_tz text,p_rule jsonb,p_from timestamptz,p_to timestamptz,p_expected integer) returns void
language plpgsql security invoker set search_path=pg_catalog,pg_temp as $$
begin
 perform pg_temp.calendar_assert(p_label,'recurrence',(select count(*)=p_expected from boss_private.calendar_expand(p_start,p_end,p_tz,p_rule,p_from,p_to)));
end;
$$;

select pg_temp.calendar_count('one-time intersects','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC',null,'2026-10-01 14:30Z','2026-10-01 16:00Z',1);
select pg_temp.calendar_count('one-time exclusive end','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC',null,'2026-10-01 15:00Z','2026-10-02Z',0);
select pg_temp.calendar_count('one-time exclusive range end','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC',null,'2026-09-30Z','2026-10-01 14:00Z',0);
select pg_temp.calendar_count('daily five valid occurrences','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC','{"frequency":"daily","count":5}','2026-10-01Z','2026-10-10Z',5);
select pg_temp.calendar_count('daily interval two','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC','{"frequency":"daily","interval":2,"count":5}','2026-10-01Z','2026-10-11Z',5);
select pg_temp.calendar_count('daily inclusive until','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC','{"frequency":"daily","until":"2026-10-05"}','2026-10-01Z','2026-10-10Z',5);
select pg_temp.calendar_count('daily count remains bounded after last','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC','{"frequency":"daily","count":5}','2026-11-01Z','2026-11-10Z',0);
select pg_temp.calendar_count('daily range seeking with count','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC','{"frequency":"daily","count":1000}','2028-10-01Z','2028-10-11Z',10);
select pg_temp.calendar_count('daily range seeking with until','2026-10-01 14:00Z','2026-10-01 15:00Z','UTC','{"frequency":"daily","until":"2031-10-01"}','2030-10-01Z','2030-10-11Z',10);
select pg_temp.calendar_count('weekly anchor day default','2026-10-05 14:00Z','2026-10-05 15:00Z','UTC','{"frequency":"weekly","count":4}','2026-10-01Z','2026-11-01Z',4);
select pg_temp.calendar_count('weekly selected Monday Wednesday Friday','2026-10-05 14:00Z','2026-10-05 15:00Z','UTC','{"frequency":"weekly","weekdays":[1,3,5],"count":9}','2026-10-01Z','2026-11-01Z',9);
select pg_temp.calendar_count('weekly interval two anchored ISO week','2026-10-05 14:00Z','2026-10-05 15:00Z','UTC','{"frequency":"weekly","interval":2,"weekdays":[1,3],"count":4}','2026-10-01Z','2026-11-01Z',4);
select pg_temp.calendar_assert('weekly exact dates','recurrence',(select array_agg(occurrence_key order by start_at)=array['2026-10-05T14:00:00','2026-10-07T14:00:00','2026-10-19T14:00:00','2026-10-21T14:00:00'] from boss_private.calendar_expand('2026-10-05 14:00Z','2026-10-05 15:00Z','UTC','{"frequency":"weekly","interval":2,"weekdays":[1,3],"count":4}','2026-10-01Z','2026-11-01Z')));
select pg_temp.calendar_count('weekly ISO Sunday seven','2026-10-04 14:00Z','2026-10-04 15:00Z','UTC','{"frequency":"weekly","weekdays":[7],"count":3}','2026-10-01Z','2026-11-01Z',3);
select pg_temp.calendar_count('monthly day fifteen','2026-01-15 14:00Z','2026-01-15 15:00Z','UTC','{"frequency":"monthly","count":12}','2026-01-01Z','2027-01-01Z',12);
select pg_temp.calendar_assert('monthly invalid dates skipped and count valid','recurrence',(select array_agg(occurrence_key order by start_at)=array['2026-01-31T14:00:00','2026-03-31T14:00:00','2026-05-31T14:00:00','2026-07-31T14:00:00'] from boss_private.calendar_expand('2026-01-31 14:00Z','2026-01-31 15:00Z','UTC','{"frequency":"monthly","count":4}','2026-01-01Z','2026-08-01Z')));
select pg_temp.calendar_count('monthly interval three','2026-01-15 14:00Z','2026-01-15 15:00Z','UTC','{"frequency":"monthly","interval":3,"count":4}','2026-01-01Z','2027-01-01Z',4);
select pg_temp.calendar_count('monthly leap year February29 emitted','2028-01-29 14:00Z','2028-01-29 15:00Z','UTC','{"frequency":"monthly","count":3}','2028-01-01Z','2028-04-01Z',3);
select pg_temp.calendar_count('monthly nonleap February29 skipped','2027-01-29 14:00Z','2027-01-29 15:00Z','UTC','{"frequency":"monthly","count":3}','2027-01-01Z','2027-04-01Z',2);

-- UTC offsets change while intended local start/end stay fixed.
select pg_temp.calendar_assert('Chicago spring preserves nine AM','DST',(select count(*)=4 and bool_and((start_at at time zone 'America/Chicago')::time=time '09:00') from boss_private.calendar_expand('2026-03-07 15:00Z','2026-03-07 16:00Z','America/Chicago','{"frequency":"daily","count":4}','2026-03-07Z','2026-03-12Z')));
select pg_temp.calendar_assert('Chicago spring UTC offset changes','DST',(select array_agg(start_at order by start_at)=array['2026-03-07 15:00Z'::timestamptz,'2026-03-08 14:00Z'::timestamptz,'2026-03-09 14:00Z'::timestamptz,'2026-03-10 14:00Z'::timestamptz] from boss_private.calendar_expand('2026-03-07 15:00Z','2026-03-07 16:00Z','America/Chicago','{"frequency":"daily","count":4}','2026-03-07Z','2026-03-12Z')));
select pg_temp.calendar_assert('Chicago fall UTC offset changes','DST',(select array_agg(start_at order by start_at)=array['2026-10-31 14:00Z'::timestamptz,'2026-11-01 15:00Z'::timestamptz,'2026-11-02 15:00Z'::timestamptz] from boss_private.calendar_expand('2026-10-31 14:00Z','2026-10-31 15:00Z','America/Chicago','{"frequency":"daily","count":3}','2026-10-31Z','2026-11-05Z')));
select pg_temp.calendar_assert('DST spring nonexistent starts skipped count valid','DST',(select array_agg(occurrence_key order by start_at)=array['2026-03-07T02:30:00','2026-03-09T02:30:00','2026-03-10T02:30:00'] from boss_private.calendar_expand('2026-03-07 08:30Z','2026-03-07 08:45Z','America/Chicago','{"frequency":"daily","count":3}','2026-03-07Z','2026-03-12Z')));
select pg_temp.calendar_assert('DST spring nonexistent ends skipped','DST',(select array_agg(occurrence_key order by start_at)=array['2026-03-07T01:30:00','2026-03-09T01:30:00','2026-03-10T01:30:00'] from boss_private.calendar_expand('2026-03-07 07:30Z','2026-03-07 08:30Z','America/Chicago','{"frequency":"daily","count":3}','2026-03-07Z','2026-03-12Z')));
select pg_temp.calendar_assert('DST fall ambiguous start uses later standard instant','DST',(select min(start_at)='2026-11-01 06:30Z'::timestamptz from boss_private.calendar_expand('2026-10-31 05:30Z','2026-10-31 05:45Z','America/New_York','{"frequency":"daily","count":3}','2026-11-01Z','2026-11-02Z')));
select pg_temp.calendar_assert('multi-day spring retains local end and 47hour duration','multiday',(select end_at-start_at=interval '47 hours' and (end_at at time zone 'America/Chicago')::time=time '09:00' from boss_private.calendar_expand('2026-03-07 15:00Z','2026-03-09 14:00Z','America/Chicago','{"frequency":"weekly","count":2}','2026-03-07Z','2026-03-10Z')));
select pg_temp.calendar_count('multi-day overlap from prior occurrence','2026-10-01 14:00Z','2026-10-04 14:00Z','UTC','{"frequency":"weekly","count":2}','2026-10-03Z','2026-10-04Z',1);
select pg_temp.calendar_assert('all-day DST spans correct local midnight','multiday',(select end_at-start_at=interval '23 hours' and (start_at at time zone 'America/Chicago')::time=time '00:00' and (end_at at time zone 'America/Chicago')::time=time '00:00' from boss_private.calendar_expand('2026-03-07 06:00Z','2026-03-08 06:00Z','America/Chicago','{"frequency":"daily","count":3}','2026-03-08 06:00Z','2026-03-09 05:00Z')));

do $$
declare z text;n integer;v_day date;v_start timestamptz;v_end timestamptz;
begin
 foreach z in array array['America/New_York','America/Chicago','America/Los_Angeles','Europe/London','Europe/Berlin','Australia/Sydney','Asia/Kolkata','Pacific/Auckland'] loop
  foreach v_day in array array[date '2026-03-01',date '2026-10-01'] loop
   v_start:=(v_day+time '09:00') at time zone z;v_end:=(v_day+time '10:00') at time zone z;
   perform pg_temp.calendar_assert(z||' daily local time '||v_day,'DST matrix',(select count(*)=60 and bool_and((start_at at time zone z)::time=time '09:00' and (end_at at time zone z)::time=time '10:00') from boss_private.calendar_expand(v_start,v_end,z,'{"frequency":"daily","count":60}',v_start,v_start+interval '65 days')));
   perform pg_temp.calendar_assert(z||' weekly local time '||v_day,'DST matrix',(select count(*)=12 and bool_and((start_at at time zone z)::time=time '09:00' and extract(isodow from start_at at time zone z)=extract(isodow from v_day)) from boss_private.calendar_expand(v_start,v_end,z,'{"frequency":"weekly","count":12}',v_start,v_start+interval '90 days')));
  end loop;
 end loop;
end;
$$;

insert into public.people(id,display_name) values(pg_temp.calendar_id('actor'),'SYNTHETIC recurrence actor');
insert into public.organizations(id,name,slug) values(pg_temp.calendar_id('org'),'SYNTHETIC recurrence organization','synthetic-phase3a-recurrence');
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,recurrence,created_by_person_id,updated_by_person_id)
 values(pg_temp.calendar_id('series'),pg_temp.calendar_id('org'),'SYNTHETIC weekly practice','practice','2026-10-05 14:00Z','2026-10-05 15:00Z','UTC','scheduled','{"frequency":"weekly","count":4}',pg_temp.calendar_id('actor'),pg_temp.calendar_id('actor'));
update public.events set recurrence='{"frequency":"daily","count":3}' where id=pg_temp.calendar_id('series');
select pg_temp.calendar_assert('stored omitted daily interval normalized','integrity',(select recurrence->'interval'='1'::jsonb from public.events where id=pg_temp.calendar_id('series')));
update public.events set recurrence='{"frequency":"weekly","count":4}' where id=pg_temp.calendar_id('series');
select pg_temp.calendar_assert('stored omitted weekly interval and weekday normalized','integrity',(select recurrence->'interval'='1'::jsonb and recurrence->'weekdays'='[1]'::jsonb from public.events where id=pg_temp.calendar_id('series')));
select pg_temp.calendar_assert('stored recurrence envelope equals final end','integrity',(select recurrence_end_at='2026-10-26 15:00Z'::timestamptz from public.events where id=pg_temp.calendar_id('series')));
insert into public.event_occurrence_exceptions(id,organization_id,event_id,occurrence_key,override_start_at,override_end_at,title,created_by_person_id,updated_by_person_id)
 values(pg_temp.calendar_id('exception'),pg_temp.calendar_id('org'),pg_temp.calendar_id('series'),'2026-10-12T14:00:00','2026-11-05 16:00Z','2026-11-05 17:00Z','SYNTHETIC rescheduled practice',pg_temp.calendar_id('actor'),pg_temp.calendar_id('actor'));
select pg_temp.calendar_assert('moved occurrence no longer appears original range','exceptions',(select count(*)=3 from public.events e cross join lateral boss_private.calendar_occurrences(e,'2026-10-01Z','2026-11-01Z') x where e.id=pg_temp.calendar_id('series')));
select pg_temp.calendar_assert('moved occurrence discovered outside original series envelope','exceptions',(select count(*)=1 and bool_and(x.is_exception and x.occurrence_key='2026-10-12T14:00:00' and x.start_at='2026-11-05 16:00Z'::timestamptz) from public.events e cross join lateral boss_private.calendar_occurrences(e,'2026-11-01Z','2026-12-01Z') x where e.id=pg_temp.calendar_id('series')));
select pg_temp.calendar_assert('canonical series unchanged by occurrence exception','exceptions',(select start_at='2026-10-05 14:00Z'::timestamptz and recurrence='{"frequency":"weekly","interval":1,"weekdays":[1],"count":4}'::jsonb from public.events where id=pg_temp.calendar_id('series')));
insert into public.event_occurrence_exceptions(id,organization_id,event_id,occurrence_key,status,created_by_person_id,updated_by_person_id)
 values(pg_temp.calendar_id('cancel'),pg_temp.calendar_id('org'),pg_temp.calendar_id('series'),'2026-10-19T14:00:00','canceled',pg_temp.calendar_id('actor'),pg_temp.calendar_id('actor'));
select pg_temp.calendar_assert('canceled occurrence remains in history','exceptions',(select count(*)=1 and bool_and(x.status='canceled' and x.is_exception) from public.events e cross join lateral boss_private.calendar_occurrences(e,'2026-10-19Z','2026-10-20Z') x where e.id=pg_temp.calendar_id('series')));
update public.event_occurrence_exceptions set is_active=false where id=pg_temp.calendar_id('cancel');
select pg_temp.calendar_assert('inactive exception retains history without affecting projection','exceptions',(select x.status='scheduled' and not x.is_exception from public.events e cross join lateral boss_private.calendar_occurrences(e,'2026-10-19Z','2026-10-20Z') x where e.id=pg_temp.calendar_id('series')));
select pg_temp.calendar_assert('inactive exception retained row','exceptions',(select count(*)=1 from public.event_occurrence_exceptions where id=pg_temp.calendar_id('cancel') and not is_active));

create function pg_temp.calendar_bad_rule(p_label text,p_rule jsonb) returns void language plpgsql security invoker set search_path=pg_catalog,pg_temp as $$
declare v_failed boolean:=false;
begin
 begin update public.events set recurrence=p_rule where id=pg_temp.calendar_id('series');
 exception when sqlstate 'PT422' then v_failed:=true;end;
 perform pg_temp.calendar_assert(p_label,'invalid recurrence',v_failed);
end;
$$;
select pg_temp.calendar_bad_rule('frequency unsupported','{"frequency":"hourly","count":3}');
select pg_temp.calendar_bad_rule('finite end required','{"frequency":"daily"}');
select pg_temp.calendar_bad_rule('both end types rejected','{"frequency":"daily","count":3,"until":"2026-12-01"}');
select pg_temp.calendar_bad_rule('count zero rejected','{"frequency":"daily","count":0}');
select pg_temp.calendar_bad_rule('count over limit rejected','{"frequency":"daily","count":1001}');
select pg_temp.calendar_bad_rule('count string rejected','{"frequency":"daily","count":"3"}');
select pg_temp.calendar_bad_rule('interval zero rejected','{"frequency":"daily","interval":0,"count":3}');
select pg_temp.calendar_bad_rule('interval over limit rejected','{"frequency":"daily","interval":53,"count":3}');
select pg_temp.calendar_bad_rule('interval fractional rejected','{"frequency":"daily","interval":1.5,"count":3}');
select pg_temp.calendar_bad_rule('until past horizon rejected','{"frequency":"daily","until":"2031-10-06"}');
select pg_temp.calendar_bad_rule('until before anchor rejected','{"frequency":"daily","until":"2026-10-04"}');
select pg_temp.calendar_bad_rule('until invalid date rejected','{"frequency":"daily","until":"2026-02-30"}');
select pg_temp.calendar_bad_rule('weekly weekdays empty rejected','{"frequency":"weekly","weekdays":[],"count":3}');
select pg_temp.calendar_bad_rule('weekly weekdays zero rejected','{"frequency":"weekly","weekdays":[0],"count":3}');
select pg_temp.calendar_bad_rule('weekly weekdays eight rejected','{"frequency":"weekly","weekdays":[8],"count":3}');
select pg_temp.calendar_bad_rule('weekly weekdays string rejected','{"frequency":"weekly","weekdays":["1"],"count":3}');
select pg_temp.calendar_bad_rule('weekly duplicate weekdays rejected','{"frequency":"weekly","weekdays":[1,1],"count":3}');
select pg_temp.calendar_bad_rule('daily weekdays rejected','{"frequency":"daily","weekdays":[1],"count":3}');
select pg_temp.calendar_bad_rule('unknown rule field rejected','{"frequency":"daily","count":3,"authority":"admin"}');
select pg_temp.calendar_bad_rule('count cadence beyond horizon rejected','{"frequency":"monthly","interval":52,"count":3}');

do $$
declare v_failed boolean;
begin
 v_failed:=false;
 begin update public.events set start_at='2026-11-01 05:30Z',end_at='2026-11-01 05:45Z',timezone='America/New_York' where id=pg_temp.calendar_id('series');
 exception when sqlstate 'PT422' then v_failed:=true;end;
 perform pg_temp.calendar_assert('earlier fold anchor rejected instead of silent shift','DST integrity',v_failed);
 v_failed:=false;
 begin update public.events set timezone='Made/Up' where id=pg_temp.calendar_id('series');exception when sqlstate 'PT422' then v_failed:=true;end;
 perform pg_temp.calendar_assert('invalid timezone rejected','integrity',v_failed);
 v_failed:=false;
 begin update public.events set all_day=true where id=pg_temp.calendar_id('series');exception when sqlstate 'PT422' then v_failed:=true;end;
 perform pg_temp.calendar_assert('all-day non-midnight rejected','integrity',v_failed);
 v_failed:=false;
 begin update public.events set start_at=start_at+interval '0.1 second' where id=pg_temp.calendar_id('series');exception when sqlstate 'PT422' then v_failed:=true;end;
 perform pg_temp.calendar_assert('subsecond anchor rejected stable occurrence key','integrity',v_failed);
 v_failed:=false;
 begin perform * from boss_private.calendar_expand('2026-10-01Z','2026-10-02Z','UTC',null,'2026-10-01Z','2032-10-01Z');exception when sqlstate 'PT422' then v_failed:=true;end;
 perform pg_temp.calendar_assert('internal expansion range bounded','boundedness',v_failed);
 v_failed:=false;
 begin perform * from boss_private.calendar_expand('2026-10-01Z','2026-10-02Z','UTC',null,'2026-10-01Z','infinity');exception when sqlstate 'PT422' then v_failed:=true;end;
 perform pg_temp.calendar_assert('infinite expansion rejected','boundedness',v_failed);
end;
$$;

update public.events set status='canceled' where id=pg_temp.calendar_id('series');
select pg_temp.calendar_assert('whole canceled series dominates scheduled exception','exceptions',(select bool_and(x.status='canceled') from public.events e cross join lateral boss_private.calendar_occurrences(e,'2026-10-01Z','2026-12-01Z') x where e.id=pg_temp.calendar_id('series')));
update public.events set status='scheduled' where id=pg_temp.calendar_id('series');

-- Execute the projection as actual authenticated/anonymous database roles.
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (pg_temp.calendar_id('auth-actor'),'synthetic-calendar-actor@example.invalid',now(),false),
 (pg_temp.calendar_id('auth-outsider'),'synthetic-calendar-outsider@example.invalid',now(),false);
insert into public.people(id,display_name) values(pg_temp.calendar_id('outsider'),'SYNTHETIC calendar outsider');
insert into public.user_accounts(auth_user_id,person_id,account_status) values
 (pg_temp.calendar_id('auth-actor'),pg_temp.calendar_id('actor'),'active'),(pg_temp.calendar_id('auth-outsider'),pg_temp.calendar_id('outsider'),'active');
insert into auth.sessions(id,user_id) values
 (pg_temp.calendar_id('session-actor'),pg_temp.calendar_id('auth-actor')),(pg_temp.calendar_id('session-outsider'),pg_temp.calendar_id('auth-outsider'));
insert into public.role_assignments(person_id,role_id,scope_type) select pg_temp.calendar_id('actor'),id,'platform' from public.roles where key='platform_administrator';
insert into public.organization_modules(organization_id,module_id,status,configuration)
 select pg_temp.calendar_id('org'),id,'active','{"public_schedules":true}' from public.modules where key='calendar';
insert into public.venues(id,organization_id,name,address_line1,instructions,created_by_person_id,updated_by_person_id)
 values(pg_temp.calendar_id('private-venue'),pg_temp.calendar_id('org'),'SYNTHETIC private venue','SYNTHETIC private address','SYNTHETIC private instructions',pg_temp.calendar_id('actor'),pg_temp.calendar_id('actor'));
insert into public.event_targets(organization_id,event_id,target_type,target_id)
 values(pg_temp.calendar_id('org'),pg_temp.calendar_id('series'),'organization',pg_temp.calendar_id('org'));
update public.events set visibility='public',publication_state='published',venue_id=pg_temp.calendar_id('private-venue'),description='SYNTHETIC member-only description',instructions='SYNTHETIC private schedule instructions',arrival_at=start_at-interval '15 minutes' where id=pg_temp.calendar_id('series');
grant select,insert on pg_temp.phase3a_recurrence_assertions to authenticated,anon;
grant execute on function pg_temp.calendar_id(text),pg_temp.calendar_assert(text,text,boolean) to authenticated,anon;
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.calendar_id('auth-actor'),'role','authenticated','is_anonymous',false,'session_id',pg_temp.calendar_id('session-actor'))::text,true);
set local role authenticated;
select pg_temp.calendar_assert('authenticated admin calendar projection executes','projection',
 (select jsonb_array_length(r->'organizations')=1 and jsonb_array_length(r->'occurrences')=3 and (r->'capabilities'->>'create')::boolean
  from (select public.boss_calendar_read(jsonb_build_object('view','organization','organization_id',pg_temp.calendar_id('org'),'from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z')) r) q));
select pg_temp.calendar_assert('authenticated admin raw full event row','RLS',(select count(*)=1 from public.events where id=pg_temp.calendar_id('series')));
select pg_temp.calendar_assert('authorized manager private venue option','projection',
 (select jsonb_array_length(r->'venues')=1 and r->'venues'->0->>'address_line1'='SYNTHETIC private address'
  from (select public.boss_calendar_read(jsonb_build_object('view','organization','organization_id',pg_temp.calendar_id('org'),'from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z')) r) q));
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.calendar_id('auth-outsider'),'role','authenticated','is_anonymous',false,'session_id',pg_temp.calendar_id('session-outsider'))::text,true);
set local role authenticated;
select pg_temp.calendar_assert('published outsider projection executes safely','projection',
 (select jsonb_array_length(r->'organizations')=0 and jsonb_array_length(r->'venues')=0 and jsonb_array_length(r->'occurrences')=3
  and not (r->'features'->>'public_schedules')::boolean
  and r->'occurrences'->0->>'description' is null and r->'occurrences'->0->>'instructions' is null and r->'occurrences'->0->>'arrival_at' is null
  and r->'occurrences'->0->>'venue_id' is null and jsonb_array_length(r->'occurrences'->0->'reminders')=0
  from (select public.boss_calendar_read(jsonb_build_object('view','organization','organization_id',pg_temp.calendar_id('org'),'from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z')) r) q));
select pg_temp.calendar_assert('published outsider cannot read full canonical rows','RLS',(select count(*)=0 from public.events where id=pg_temp.calendar_id('series')));
select pg_temp.calendar_assert('published outsider cannot read private venue row','RLS',(select count(*)=0 from public.venues where id=pg_temp.calendar_id('private-venue')));
select pg_temp.calendar_assert('published outsider cannot read occurrence instruction row','RLS',(select count(*)=0 from public.event_occurrence_exceptions where event_id=pg_temp.calendar_id('series')));
reset role;
set local role anon;
select pg_temp.calendar_assert('anonymous explicitly published schedule only','public projection',
 (select jsonb_array_length(r->'occurrences')=3 and not(r->'occurrences'->0 ? 'instructions') and not(r->'occurrences'->0 ? 'arrival_at')
  and r->'occurrences'->0->>'venue' is null
  from (select public.boss_calendar_public_read(jsonb_build_object('organization_id',pg_temp.calendar_id('org'),'from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z')) r) q));
select pg_temp.calendar_assert('anonymous no boss_private schema usage','ACL',not has_schema_privilege(current_user,'boss_private','USAGE'));
reset role;
update public.events set publication_state='unpublished' where id=pg_temp.calendar_id('series');
set local role anon;
select pg_temp.calendar_assert('anonymous unpublished schedule closed','public projection',
 (select jsonb_array_length(r->'occurrences')=0 from (select public.boss_calendar_public_read(jsonb_build_object('organization_id',pg_temp.calendar_id('org'),'from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z')) r) q));
reset role;
\o
select category,count(*) assertions from pg_temp.phase3a_recurrence_assertions group by category order by category;
select count(*) as passed_assertions from pg_temp.phase3a_recurrence_assertions;
rollback;
