-- One bounded, caller-authorized RPC read. Used only by performance/run.sh.
-- Prints scalar cardinalities and function statistics, never RPC/claim payloads.
-- case_name: notifications_summary|notifications_inbox|attendance|calendar|
--            admin|registration|communications|volunteers
begin;
set local timezone='UTC';
set local statement_timeout='8s';
select set_config('boss.perf_case', :'case_name', true) as case_setting \gset
create temp table boss_perf_read_sample(status text not null,sqlstate text,
 elapsed_ms numeric not null,cardinalities jsonb not null) on commit drop;
grant insert,select on boss_perf_read_sample to authenticated;
select boss_perf.actor('guardian') as actor_setting \gset
set local role authenticated;
do $$
declare requested_case text:=current_setting('boss.perf_case');started timestamptz;
 result jsonb;counts jsonb;state text;outcome text:='SUCCESS';duration numeric;
begin
 started:=clock_timestamp();
 begin
  case requested_case
   when 'notifications_summary' then
    result:=public.boss_notifications_read(jsonb_build_object('view','summary','limit',5));
   when 'notifications_inbox' then
    result:=public.boss_notifications_read(jsonb_build_object('view','inbox','limit',50,'organization_id',boss_perf.id('org-1')));
   when 'attendance' then
    result:=public.boss_attendance_read(jsonb_build_object('view','family',
     'from',to_char(now()at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
     'to',to_char((now()+interval'30 days')at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"')));
   when 'calendar' then
    result:=public.boss_calendar_read(jsonb_build_object('view','personal',
     'from',to_char(date_trunc('day',now())at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
     'to',to_char((date_trunc('day',now())+interval'14 days')at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"')));
   when 'admin' then result:=public.boss_admin_read('home',null,null);
   when 'registration' then result:=public.boss_registration_read('{"view":"family"}'::jsonb);
   when 'communications' then result:=public.boss_communications_read('{"view":"summary"}'::jsonb);
   when 'volunteers' then
    result:=public.boss_volunteers_read(jsonb_build_object('view','upcoming',
     'from',to_char(now()at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
     'to',to_char((now()+interval'30 days')at time zone'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"')));
   else raise exception 'Unknown performance read case' using errcode='22023';
  end case;
 exception when sqlstate '57014' then outcome:='ERROR';state:=sqlstate;
  when others then outcome:='ERROR';state:=sqlstate;
 end;
 duration:=round((extract(epoch from clock_timestamp()-started)*1000)::numeric,3);
 select coalesce(jsonb_object_agg(key,jsonb_array_length(value)),'{}'::jsonb)
 into counts from jsonb_each(coalesce(result,'{}'::jsonb))where jsonb_typeof(value)='array';
 if result?'unread_count' then counts:=counts||jsonb_build_object('unread_count',(result->>'unread_count')::bigint);end if;
 if jsonb_typeof(result->'occurrences')='array' then
  counts:=counts||jsonb_build_object('projected_subjects',coalesce((select sum(jsonb_array_length(x->'subjects'))
   from jsonb_array_elements(result->'occurrences')x where jsonb_typeof(x->'subjects')='array'),0));
 end if;
 insert into boss_perf_read_sample values(outcome,state,duration,counts);
end$$;
reset role;
select jsonb_build_object('case',current_setting('boss.perf_case'),'status',sample.status,
 'sqlstate',sample.sqlstate,'elapsed_ms',sample.elapsed_ms,'cardinalities',sample.cardinalities,
 'functions',coalesce((select jsonb_agg(jsonb_build_object('schema',schemaname,'function',funcname,
 'calls',calls,'total_ms',round(total_time::numeric,3),'self_ms',round(self_time::numeric,3))
 order by total_time desc,schemaname,funcname)from pg_stat_xact_user_functions where calls>0),'[]'::jsonb))
from boss_perf_read_sample sample;
rollback;
