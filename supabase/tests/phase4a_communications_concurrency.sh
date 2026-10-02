#!/usr/bin/env bash
# Real two-connection RPC serialization, disposable Unix socket only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}"
: "${PGHOST:?Disposable runner required}"
: "${PGPORT:?Disposable runner required}"
: "${PGDATABASE:?Disposable runner required}"
: "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Communications races require the private disposable runner socket.' >&2;exit 1
fi
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses') = ''") != t ]];then printf '%s\n' 'Communications races reject a TCP listener.' >&2;exit 1;fi
writer_pid='';contender_pid='';input_open=false
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;if [[ -n "$writer_pid" ]];then kill "$writer_pid" >/dev/null 2>&1 || true;wait "$writer_pid" >/dev/null 2>&1 || true;fi;if [[ -n "$contender_pid" ]];then kill "$contender_pid" >/dev/null 2>&1 || true;wait "$contender_pid" >/dev/null 2>&1 || true;fi;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
"${psql_cmd[@]}" --command "begin;
insert into auth.users(id,email,email_confirmed_at) values('c4aa1000-0000-4000-8000-000000000001','synthetic-race@phase4a.example.invalid',now()-interval '1 day');
insert into auth.sessions(id,user_id) values('c4aa2000-0000-4000-8000-000000000001','c4aa1000-0000-4000-8000-000000000001');
insert into public.people(id,display_name,date_of_birth) values('c4aa3000-0000-4000-8000-000000000001','Synthetic Phase4A Race Actor','1980-01-01');
insert into public.user_accounts(auth_user_id,person_id,account_status) values('c4aa1000-0000-4000-8000-000000000001','c4aa3000-0000-4000-8000-000000000001','active');
insert into public.role_assignments(person_id,role_id,scope_type) select 'c4aa3000-0000-4000-8000-000000000001',id,'platform' from public.roles where key='platform_administrator';
insert into public.organizations(id,name,slug) values('c4aa4000-0000-4000-8000-000000000001','Synthetic Phase4A Race Organization','phase4a-race');
insert into public.organization_modules(organization_id,module_id,status,configuration) select 'c4aa4000-0000-4000-8000-000000000001',id,'active','{}' from public.modules where key='messaging';
insert into public.communication_threads(id,organization_id,kind,title,scope_type,scope_id,created_by_person_id) values('c4aa5000-0000-4000-8000-000000000001','c4aa4000-0000-4000-8000-000000000001','organization_staff','Synthetic RPC race','organization','c4aa4000-0000-4000-8000-000000000001','c4aa3000-0000-4000-8000-000000000001');commit;" >"$race_dir/phase4a-comm-setup.out"
await_state(){ local app=$1 expected=$2 query deadline=$((SECONDS+15));if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%boss_communications_mutate%'";else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi;while (( SECONDS<deadline ));do if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.05;done;printf 'Communication race did not synchronize %s.\n' "$app" >&2;return 1;}
race(){
 local kind=$1 n=$2 isolation=$3 expected=$4 writer_name="boss_phase4a_comm_${1}_${2}_writer" contender_name="boss_phase4a_comm_${1}_${2}_contender" fifo="$race_dir/phase4a-comm-${1}-${2}.stdin" req1 req2 cmd1 cmd2 status
 printf -v req1 'c4aa6000-0000-4000-8000-%012d' "$((n*2))";printf -v req2 'c4aa6000-0000-4000-8000-%012d' "$((n*2+1))"
 cmd1='{"operation":"message.send","input":{"thread_id":"c4aa5000-0000-4000-8000-000000000001","body":"Synthetic concurrent message"}}';cmd2="$cmd1"
 if [[ "$kind" == retry ]];then req2="$req1";fi
 if [[ "$kind" == read ]];then cmd1='{"operation":"read.thread","input":{"thread_id":"c4aa5000-0000-4000-8000-000000000001","through_sequence":2}}';cmd2='{"operation":"read.thread","input":{"thread_id":"c4aa5000-0000-4000-8000-000000000001","through_sequence":1}}';fi
 local claims='{"sub":"c4aa1000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"c4aa2000-0000-4000-8000-000000000001"}'
 mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/phase4a-comm-$n-writer.out" 2>"$race_dir/phase4a-comm-$n-writer.err" & writer_pid=$!;exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='$writer_name';begin;set local role authenticated;select set_config('request.jwt.claims','$claims',true);select public.boss_communications_mutate('$req1','$cmd1');" >&9
 await_state "$writer_name" ready
 "${psql_cmd[@]}" --command "set application_name='$contender_name';begin isolation level $isolation;set local role authenticated;select set_config('request.jwt.claims','$claims',true);select public.boss_communications_mutate('$req2','$cmd2');commit;" >"$race_dir/phase4a-comm-$n-contender.out" 2>"$race_dir/phase4a-comm-$n-contender.err" & contender_pid=$!
 await_state "$contender_name" waiting
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid";writer_pid=''
 if wait "$contender_pid";then status=0;else status=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$status" != 0 ]];then cat "$race_dir/phase4a-comm-$n-contender.err" >&2;return 1;fi
 if [[ "$expected" == conflict && "$status" == 0 ]];then printf '%s\n' 'Higher-isolation concurrent mutation unexpectedly committed.' >&2;return 1;fi
 if [[ "$expected" == conflict ]] && ! rg -q 'PT409' "$race_dir/phase4a-comm-$n-contender.err";then cat "$race_dir/phase4a-comm-$n-contender.err" >&2;return 1;fi
}
race retry 1 'read committed' success
if [[ $("${psql_cmd[@]}" --command "select count(*) from public.communication_messages where thread_id='c4aa5000-0000-4000-8000-000000000001'") != 1 ]];then printf '%s\n' 'Concurrent request replay duplicated message.' >&2;exit 1;fi
race unique 2 'read committed' success
if [[ $("${psql_cmd[@]}" --command "select count(*)=3 and count(distinct sequence_number)=3 and max(sequence_number)=3 from public.communication_messages where thread_id='c4aa5000-0000-4000-8000-000000000001'") != t ]];then printf '%s\n' 'Concurrent message sequencing failed.' >&2;exit 1;fi
race read 3 'read committed' success
if [[ $("${psql_cmd[@]}" --command "select through_sequence=2 from public.communication_read_state where thread_id='c4aa5000-0000-4000-8000-000000000001' and person_id='c4aa3000-0000-4000-8000-000000000001'") != t ]];then printf '%s\n' 'Concurrent lower watermark regressed read state.' >&2;exit 1;fi
race unique 4 'repeatable read' conflict
race unique 5 'serializable' conflict
printf '%s\n' 'Phase 4A communications: 5 coordinated concurrency assertions passed.'
