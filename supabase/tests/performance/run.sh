#!/usr/bin/env bash
# Optional bounded Phase 4B profiling; never connects to canonical Supabase.
# Default: all migrations, owned_events=8, three samples and three shell batches.
# Baseline: --migration-limit 29 records expected 57014 cancellations.
# Times are diagnostic evidence; structural regression suite remains separate.
set -euo pipefail
umask 077
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_dir=$(cd -- "$test_dir/../../.." && pwd)
migration_limit=0
owned_events=8
repetitions=3
batches=3
evidence_dir=''
while [[ $# -gt 0 ]];do
 case "$1" in
  --migration-limit|--owned-events|--repetitions|--batches|--evidence-dir)
   if [[ $# -lt 2 ]];then printf 'Missing value for %s\n' "$1" >&2;exit 1;fi
   case "$1" in
    --migration-limit)migration_limit=$2;;--owned-events)owned_events=$2;;
    --repetitions)repetitions=$2;;--batches)batches=$2;;--evidence-dir)evidence_dir=$2;;
   esac;shift 2;;
  *)printf '%s\n' 'Usage: performance/run.sh [--migration-limit 29] [--owned-events 1|2|4|8] [--repetitions 3] [--batches 3] [--evidence-dir /private/tmp/path]' >&2;exit 1;;
 esac
done
for value in "$migration_limit" "$repetitions" "$batches";do
 if [[ ! "$value" =~ ^[0-9]+$ ]];then printf '%s\n' 'Counts must be nonnegative integers.' >&2;exit 1;fi
done
if [[ ! "$owned_events" =~ ^(1|2|4|8)$ || "$repetitions" -lt 1 || "$repetitions" -gt 3 || "$batches" -gt 3 ]];then
 printf '%s\n' 'Use owned-events 1/2/4/8, repetitions 1..3 and batches 0..3.' >&2;exit 1
fi
if [[ -n "${PG_BINDIR:-}" ]];then postgres_bin_dir=$PG_BINDIR
elif command -v pg_config >/dev/null 2>&1;then postgres_bin_dir=$(pg_config --bindir)
else printf '%s\n' 'PostgreSQL17 binaries required; set PG_BINDIR.' >&2;exit 1;fi
for binary in postgres initdb pg_ctl psql;do
 if [[ ! -x "$postgres_bin_dir/$binary" ]];then printf 'Missing PostgreSQL binary %s\n' "$binary" >&2;exit 1;fi
done
if [[ $("$postgres_bin_dir/postgres" --version) != *'PostgreSQL) 17.'* || $(id -u) == 0 ]];then
 printf '%s\n' 'Requires PostgreSQL17 and an unprivileged OS user.' >&2;exit 1
fi
python_bin=$(command -v python3)
if [[ -z "$evidence_dir" ]];then evidence_dir=$(mktemp -d /tmp/boss-phase4b-perf-evidence.XXXXXX)
else
 case "$evidence_dir" in /tmp/*|/private/tmp/*);;*)printf '%s\n' 'Evidence must be outside Git under /tmp or /private/tmp.' >&2;exit 1;;esac
 if [[ -e "$evidence_dir" ]];then printf '%s\n' 'Evidence directory must be new.' >&2;exit 1;fi
 mkdir -m 700 "$evidence_dir"
fi
test_run_dir=$(mktemp -d /tmp/boss-perf-harness.XXXXXX)
data_dir=$test_run_dir/data
socket_dir=$test_run_dir/socket
mkdir -m 700 "$socket_dir"
cleanup(){
 local result=$?
 trap - EXIT INT TERM
 if [[ -s "$data_dir/postmaster.pid" ]];then
  if ! env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C PGPASSFILE=/dev/null "$postgres_bin_dir/pg_ctl" --pgdata "$data_dir" --mode immediate --wait stop >/dev/null 2>&1;then
   printf 'Disposable shutdown failed; cluster preserved at %s\n' "$test_run_dir" >&2;exit 1
  fi
 fi
 rm -rf -- "$test_run_dir"
 printf 'Private evidence: %s\n' "$evidence_dir"
 printf '%s\n' 'Disposable PostgreSQL cluster removed.'
 exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C PGPASSFILE=/dev/null "$postgres_bin_dir/initdb" --pgdata "$data_dir" --username boss_test_admin \
 --auth-local trust --auth-host reject --encoding UTF8 --no-locale >"$evidence_dir/initdb.log" 2>&1
env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C PGPASSFILE=/dev/null "$postgres_bin_dir/pg_ctl" --pgdata "$data_dir" --log "$evidence_dir/postgres.log" \
 --options "-c listen_addresses='' -c unix_socket_directories='$socket_dir' -c unix_socket_permissions=0700 -c log_statement=none -c log_min_error_statement=panic -c jit=off -c track_functions=all" --wait start >/dev/null
psql_bootstrap=(env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C PGPASSFILE=/dev/null "$postgres_bin_dir/psql" --no-psqlrc --no-password \
 --host "$socket_dir" --port 5432 --username boss_test_admin --dbname postgres --set ON_ERROR_STOP=1 --set VERBOSITY=terse --quiet)
psql_migrate=(env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C PGPASSFILE=/dev/null "$postgres_bin_dir/psql" --no-psqlrc --no-password \
 --host "$socket_dir" --port 5432 --username postgres --dbname postgres --set ON_ERROR_STOP=1 --set VERBOSITY=terse --quiet)
"${psql_bootstrap[@]}" --file "$test_dir/../local-bootstrap.sql" >"$evidence_dir/bootstrap.log" 2>&1
shopt -s nullglob
migrations=("$repository_dir"/supabase/migrations/*.sql)
if [[ ${#migrations[@]} == 0 || "$migration_limit" -gt ${#migrations[@]} ]];then printf '%s\n' 'Invalid migration selection.' >&2;exit 1;fi
if [[ "$migration_limit" == 0 ]];then migration_limit=${#migrations[@]};fi
for ((index=0;index<migration_limit;index++));do
 "${psql_migrate[@]}" --single-transaction --file "${migrations[$index]}" >"$evidence_dir/migration-$index.log" 2>&1
done
"${psql_migrate[@]}" --command 'create database boss_phase4b_performance template postgres owner postgres' >/dev/null
psql_fixture=(env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C PGPASSFILE=/dev/null "$postgres_bin_dir/psql" --no-psqlrc --no-password \
 --host "$socket_dir" --port 5432 --username postgres --dbname boss_phase4b_performance --set ON_ERROR_STOP=1 --set VERBOSITY=terse --quiet)
"${psql_fixture[@]}" --set boss_disposable=true --set owned_events="$owned_events" --file "$test_dir/phase4b_fixture.sql" >"$evidence_dir/fixture.log" 2>&1

# Each concurrent read gets its own connection and cleared client environment.
env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C PGPASSFILE=/dev/null "$python_bin" - "$postgres_bin_dir/psql" "$socket_dir" "$test_dir/read.sql" \
 "$evidence_dir" "$migration_limit" "$owned_events" "$repetitions" "$batches" <<'PY'
import concurrent.futures, json, os, pathlib, statistics, subprocess, sys, time
psql,socket,read_file,evidence,migrations,owned,repetitions,batches=sys.argv[1:]
evidence=pathlib.Path(evidence)
migrations,owned,repetitions,batches=map(int,(migrations,owned,repetitions,batches))
baseline=migrations==29
cases=('notifications_summary','notifications_inbox','attendance','calendar')
layout=('admin','calendar','registration','communications','notifications_summary','attendance','volunteers','notifications_inbox')

def read_case(case,phase,iteration):
    started=time.monotonic()
    command=[psql,'--no-psqlrc','--no-password','--host',socket,'--port','5432','--username','postgres',
             '--dbname','boss_phase4b_performance','--set','ON_ERROR_STOP=1','--set','VERBOSITY=terse',
             '--quiet','--no-align','--tuples-only','--set',f'case_name={case}','--file',read_file]
    try:
        completed=subprocess.run(command,capture_output=True,text=True,timeout=15,
                                 env={'PATH':'/usr/bin:/bin','LC_ALL':'C','LANG':'C','PGPASSFILE':'/dev/null'})
        samples=[json.loads(line) for line in completed.stdout.splitlines() if line.startswith('{')]
        if completed.returncode or len(samples)!=1:
            sample={'case':case,'status':'HARNESS_ERROR','sqlstate':None,'elapsed_ms':None,'cardinalities':{},'functions':[]}
            (evidence/f'{phase}-{iteration}-{case}.stderr').write_text(completed.stderr)
        else: sample=samples[0]
    except subprocess.TimeoutExpired:
        sample={'case':case,'status':'HARNESS_TIMEOUT','sqlstate':None,'elapsed_ms':None,'cardinalities':{},'functions':[]}
    sample.update(phase=phase,iteration=iteration,client_elapsed_ms=round((time.monotonic()-started)*1000,3))
    return sample

individual=[]
for iteration in range(1,repetitions+1):
    for case in cases:
        sample=read_case(case,'individual',iteration)
        individual.append(sample)
        print(json.dumps({k:sample[k] for k in ('phase','iteration','case','status','sqlstate','elapsed_ms','cardinalities')}),flush=True)
parallel=[]
batch_summary=[]
for iteration in range(1,batches+1):
    started=time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results=list(pool.map(lambda case:read_case(case,'parallel',iteration),layout))
    parallel.extend(results)
    batch={'iteration':iteration,'requests':len(results),'elapsed_ms':round((time.monotonic()-started)*1000,3),
           'statuses':{x['case']:x['status'] for x in results},'sqlstates':{x['case']:x['sqlstate'] for x in results}}
    batch_summary.append(batch)
    print(json.dumps({'parallel_batch':batch}),flush=True)
summary=[]
for case in cases:
    rows=[x for x in individual if x['case']==case]
    elapsed=[x['elapsed_ms'] for x in rows if x['elapsed_ms'] is not None]
    summary.append({'case':case,'samples':len(rows),'successes':sum(x['status']=='SUCCESS' for x in rows),
                    'sqlstates':[x['sqlstate'] for x in rows],'min_ms':min(elapsed) if elapsed else None,
                    'median_ms':statistics.median(elapsed) if elapsed else None,'max_ms':max(elapsed) if elapsed else None})
failures=[x for x in individual+parallel if x['status']!='SUCCESS' and not(baseline and x['sqlstate']=='57014')]
report={'migration_count':migrations,'baseline':baseline,'owned_events':owned,'statement_timeout_ms':8000,
        'individual_summary':summary,'individual':individual,'parallel_batches':batch_summary,'parallel':parallel,
        'unexpected_failures':len(failures),'query_contract':'Application shell defaults: Calendar UTC midnight/14 days; Attendance and Volunteers now/30 days; no organization filter except page Notifications inbox org-1. Fixture helper query uses a longer anchor-relative month and is not used here.'}
(evidence/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'individual_summary':summary,'unexpected_failures':len(failures)}),flush=True)
sys.exit(1 if failures else 0)
PY
