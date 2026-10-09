#!/usr/bin/env bash
# Actual two-connection volunteer capacity/retry/cancellation serialization.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then printf '%s\n' 'Volunteer races require the private disposable runner socket.' >&2;exit 1;fi
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses') = ''") != t ]];then printf '%s\n' 'Volunteer races reject a TCP listener.' >&2;exit 1;fi
writer_pid='';contender_pid='';input_open=false
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
"${psql_cmd[@]}" --command "begin;
insert into auth.users(id,email,email_confirmed_at) values('c4bb1000-0000-4000-8000-000000000001','synthetic-volunteer1@phase4b.example.invalid',now()-interval '1 day'),('c4bb1000-0000-4000-8000-000000000002','synthetic-volunteer2@phase4b.example.invalid',now()-interval '1 day');
insert into auth.sessions(id,user_id) values('c4bb2000-0000-4000-8000-000000000001','c4bb1000-0000-4000-8000-000000000001'),('c4bb2000-0000-4000-8000-000000000002','c4bb1000-0000-4000-8000-000000000002');
insert into public.people(id,display_name,date_of_birth) values('c4bb3000-0000-4000-8000-000000000001','Synthetic volunteer race adult1','1980-01-01'),('c4bb3000-0000-4000-8000-000000000002','Synthetic volunteer race adult2','1980-01-01');
insert into public.user_accounts(auth_user_id,person_id,account_status) values('c4bb1000-0000-4000-8000-000000000001','c4bb3000-0000-4000-8000-000000000001','active'),('c4bb1000-0000-4000-8000-000000000002','c4bb3000-0000-4000-8000-000000000002','active');
insert into public.role_assignments(person_id,role_id,scope_type) select 'c4bb3000-0000-4000-8000-000000000001',id,'platform' from public.roles where key='platform_administrator';
insert into public.organizations(id,name,slug) values('c4bb4000-0000-4000-8000-000000000001','Synthetic volunteer race organization','phase4b-volunteer-race');
insert into public.organization_memberships(organization_id,person_id) values('c4bb4000-0000-4000-8000-000000000001','c4bb3000-0000-4000-8000-000000000001'),('c4bb4000-0000-4000-8000-000000000001','c4bb3000-0000-4000-8000-000000000002');
insert into public.organization_modules(organization_id,module_id,status,configuration) select 'c4bb4000-0000-4000-8000-000000000001',id,'active','{\"volunteers\":true,\"self_signup\":true,\"minimum_signup_age\":18}' from public.modules where key='volunteers';
insert into public.volunteer_role_definitions(id,organization_id,name,created_by_person_id,updated_by_person_id) values('c4bb5000-0000-4000-8000-000000000001','c4bb4000-0000-4000-8000-000000000001','Synthetic race duty','c4bb3000-0000-4000-8000-000000000001','c4bb3000-0000-4000-8000-000000000001');
insert into public.volunteer_shifts(id,organization_id,role_id,title,scope_type,scope_id,start_at,end_at,capacity,status,created_by_person_id,updated_by_person_id) select ('c4bb6000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c4bb4000-0000-4000-8000-000000000001','c4bb5000-0000-4000-8000-000000000001','Synthetic concurrent duty','organization','c4bb4000-0000-4000-8000-000000000001',now()+interval '1 day',now()+interval '1 day 1 hour',case when n=5 then 2 else 1 end,'open','c4bb3000-0000-4000-8000-000000000001','c4bb3000-0000-4000-8000-000000000001' from generate_series(1,7)n;commit;" >"$race_dir/phase4b-vol-setup.out"
claims(){ printf '{"sub":"c4bb1000-0000-4000-8000-%012d","role":"authenticated","is_anonymous":false,"session_id":"c4bb2000-0000-4000-8000-%012d"}' "$1" "$1"; }
participant_failure(){
 local app=$1 reason=$2 error_file=$3
 printf 'Volunteer race participant %s %s.\n' "$app" "$reason" >&2
 # Retain the failure category without printing SQL, synthetic claims or context.
 awk '/(ERROR|FATAL):/ {for(i=1;i<NF;i++) if($i=="ERROR:" || $i=="FATAL:") {code=$(i+1);sub(/:$/,"",code);if(code~/^[0-9A-Z]{5}$/) print "Participant SQLSTATE: " code;exit}}' "$error_file" >&2
}
await_state(){
 local app=$1 expected=$2 participant_pid=$3 error_file=$4 query deadline=$((SECONDS+60))
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%boss_volunteers_mutate%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while (( SECONDS<deadline ));do
  if [[ -s "$error_file" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$error_file";then participant_failure "$app" 'failed before synchronization' "$error_file";return 1;fi
  if ! kill -0 "$participant_pid" >/dev/null 2>&1;then participant_failure "$app" 'exited before synchronization' "$error_file";return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi
  sleep 0.05
 done
 participant_failure "$app" "did not reach $expected within 60 seconds" "$error_file"
 # This metadata is safe even when a failing query includes request claims.
 "${psql_cmd[@]}" --command "set statement_timeout='5s';select state,coalesce(wait_event_type,'none') from pg_stat_activity where application_name='$app';" >&2 || true
 return 1
}
race(){
 local kind=$1 n=$2 isolation=$3 expected=$4 writer_name="boss_phase4b_vol_${1}_${2}_writer" contender_name="boss_phase4b_vol_${1}_${2}_contender" fifo="$race_dir/phase4b-vol-${1}-${2}.stdin" req1 req2 cmd1 cmd2 who2=2 assignment_id version status sid
 printf -v req1 'c4bb7000-0000-4000-8000-%012d' "$((n*10))";printf -v req2 'c4bb7000-0000-4000-8000-%012d' "$((n*10+1))";printf -v sid 'c4bb6000-0000-4000-8000-%012d' "$n"
 cmd1="{\"operation\":\"assignment.signup\",\"input\":{\"shift_id\":\"$sid\"}}";cmd2="$cmd1"
 if [[ "$kind" == retry ]];then req2="$req1";who2=1;fi
 if [[ "$kind" == sameperson ]];then who2=1;fi
 if [[ "$kind" == cancel || "$kind" == resize ]];then
 "${psql_cmd[@]}" --command "begin;set local role authenticated;select set_config('request.jwt.claims','$(claims 1)',true);select public.boss_volunteers_mutate('c4bb7000-0000-4000-9000-00000000000$n','$cmd1');commit;" >"$race_dir/phase4b-vol-$n-prep.out"
 assignment_id=$("${psql_cmd[@]}" --command "select id from public.volunteer_assignments where shift_id='$sid' and person_id='c4bb3000-0000-4000-8000-000000000001'")
 if [[ "$kind" == cancel ]];then cmd1="{\"operation\":\"assignment.cancel\",\"input\":{\"assignment_id\":\"$assignment_id\",\"expected_version\":1}}";
 else version=$("${psql_cmd[@]}" --command "select version from public.volunteer_shifts where id='$sid'");cmd1=$("${psql_cmd[@]}" --command "select jsonb_build_object('operation','shift.upsert','input',jsonb_build_object('organization_id',organization_id,'shift_id',id,'expected_version',$version,'role_id',role_id,'title',title,'scope_type',scope_type,'scope_id',scope_id,'start_at',start_at,'end_at',end_at,'capacity',1,'status',status,'visibility',visibility)) from public.volunteer_shifts where id='$sid'");fi;fi
 mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/phase4b-vol-$n-writer.out" 2>"$race_dir/phase4b-vol-$n-writer.err" & writer_pid=$!;exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='$writer_name';set statement_timeout='75s';begin;set local role authenticated;select set_config('request.jwt.claims','$(claims 1)',true);select public.boss_volunteers_mutate('$req1','$cmd1');" >&9;await_state "$writer_name" ready "$writer_pid" "$race_dir/phase4b-vol-$n-writer.err"
 "${psql_cmd[@]}" --command "set application_name='$contender_name';set statement_timeout='75s';begin isolation level $isolation;set local role authenticated;select set_config('request.jwt.claims','$(claims "$who2")',true);select public.boss_volunteers_mutate('$req2','$cmd2');commit;" >"$race_dir/phase4b-vol-$n-contender.out" 2>"$race_dir/phase4b-vol-$n-contender.err" & contender_pid=$!;await_state "$contender_name" waiting "$contender_pid" "$race_dir/phase4b-vol-$n-contender.err"
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid";writer_pid=''
 if wait "$contender_pid";then status=0;else status=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$status" != 0 ]];then cat "$race_dir/phase4b-vol-$n-contender.err" >&2;return 1;fi
 if [[ "$expected" == conflict && "$status" == 0 ]];then printf '%s\n' 'Volunteer race unexpectedly exceeded capacity or accepted stale snapshot.' >&2;return 1;fi
 if [[ "$expected" == conflict ]] && ! grep -Fq 'PT409' "$race_dir/phase4b-vol-$n-contender.err";then cat "$race_dir/phase4b-vol-$n-contender.err" >&2;return 1;fi
}
race capacity 1 'read committed' conflict
race sameperson 2 'read committed' success
race retry 3 'read committed' success
race cancel 4 'read committed' success
race resize 5 'read committed' conflict
race capacity 6 'repeatable read' conflict
race capacity 7 'serializable' conflict
if [[ $("${psql_cmd[@]}" --command "select count(*)=7 and not exists(select 1 from public.volunteer_shifts s where s.organization_id='c4bb4000-0000-4000-8000-000000000001' and (select count(*) from public.volunteer_assignments a where a.shift_id=s.id and a.status='active')>s.capacity) from public.volunteer_assignments where organization_id='c4bb4000-0000-4000-8000-000000000001' and status='active'") != t ]];then printf '%s\n' 'Volunteer capacity invariant failed.' >&2;exit 1;fi
if [[ $("${psql_cmd[@]}" --command "select count(*)=1 from public.volunteer_assignment_history where assignment_id=(select id from public.volunteer_assignments where shift_id='c4bb6000-0000-4000-8000-000000000003')") != t ]];then printf '%s\n' 'Volunteer request retry duplicated history.' >&2;exit 1;fi
printf '%s\n' 'Phase 4B volunteers: 7 coordinated concurrency assertions passed.'
