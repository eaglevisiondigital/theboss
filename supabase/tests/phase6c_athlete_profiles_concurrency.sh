#!/usr/bin/env bash
# Eight real two-connection Phase 6C races on the private disposable socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Phase6C races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase6C concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
assert_sql(){ [[ $("${psql_cmd[@]}" --command "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%phase6c-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $("${psql_cmd[@]}" --command "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4;local fifo="$race_dir/phase6c-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/$label-w.out" 2>"$race_dir/$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase6c_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase6c-writer-ready */;" >&9;await_state "boss_phase6c_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_phase6c_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/$label-c.out" 2>"$race_dir/$label-c.err"&contender_pid=$!;await_state "boss_phase6c_${label}_contender" waiting "$contender_pid"||fail "$label contender did not block";printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||fail "$label writer";writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/$label-c.err";};then fail "$label expected $expected";fi;race_count=$((race_count+1)); }
snapshot_race(){ local label=$1 writer_sql=$2 read_sql=$3 post_assert=$4;local fifo="$race_dir/phase6c-$label.stdin";mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/$label-w.out" 2>"$race_dir/$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase6c_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase6c-writer-ready */;" >&9;await_state "boss_phase6c_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set statement_timeout='8s';$read_sql" >"$race_dir/$label-read.out" 2>"$race_dir/$label-read.err"||fail "$label snapshot read";printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||fail "$label writer";writer_pid='';assert_sql "$label post-commit" "$post_assert";race_count=$((race_count+1)); }
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase6c-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase6c-race-base:session-$1')::uuid)::text,true);"; }
mutate(){ printf '%s' "$(auth "$1")select public.boss_athlete_profile_mutate(jsonb_build_object('action','$2','request_id',gen_random_uuid(),'input',$3));reset role;"; }
# Use an independent deterministic namespace because earlier concurrency suites
# intentionally retain their committed synthetic rows until the disposable
# cluster is removed. Flatten the fixture include chain and rewrite only its
# synthetic identifiers; no production migration or application behavior is
# changed by this harness isolation.
sed -e 's/boss-phase5a-test:/boss-phase6c-race-base:/g' -e 's/phase5a.example.invalid/phase6c-race.example.invalid/g' -e 's/synthetic-phase5a-/synthetic-phase6c-race-/g' "$test_dir/phase5a/fixture.sql" >"$race_dir/phase6c-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5d-test:/,"boss-phase6c-race-roster:");print}' "$test_dir/phase5d/fixture.sql" >>"$race_dir/phase6c-fixture.sql"
awk '$0!="\\ir ../phase5d/fixture.sql" {print}' "$test_dir/phase5f/fixture.sql" >>"$race_dir/phase6c-fixture.sql"
awk '$0!="\\ir ../phase5f/fixture.sql" {print}' "$test_dir/phase6b/fixture.sql" >>"$race_dir/phase6c-fixture.sql"
awk '$0!="\\ir ../phase6b/fixture.sql" {print}' "$test_dir/phase6c/fixture.sql" >>"$race_dir/phase6c-fixture.sql"
cat >"$race_dir/phase6c-setup.sql" <<SQL
begin;set local statement_timeout='8s';\ir '$race_dir/phase6c-fixture.sql'
$(auth parent)select public.boss_athlete_profile_mutate(jsonb_build_object('action','consent.grant','request_id',gen_random_uuid(),'input',jsonb_build_object('showcase_id',pg_temp.pc_id('showcase'),'showcase_revision_id',pg_temp.pc_id('showcase-revision'),'approved_categories',jsonb_build_array('overview','sports','statistics','measurables','achievements','history','media'),'expires_at',clock_timestamp()+interval'1 hour')));reset role;
$(auth parent)select public.boss_athlete_profile_mutate(jsonb_build_object('action','showcase.publish','request_id',gen_random_uuid(),'input',jsonb_build_object('showcase_id',pg_temp.pc_id('showcase'),'expected_version',3)));reset role;
$(auth parent)select public.boss_athlete_profile_mutate(jsonb_build_object('action','share.create','request_id',gen_random_uuid(),'input',jsonb_build_object('showcase_id',pg_temp.pc_id('showcase'),'token_digest',repeat('a',64),'token_prefix','aaaaaaaa','expires_at',clock_timestamp()+interval'1 hour')));reset role;commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase6c-setup.sql" >"$race_dir/setup.out" 2>"$race_dir/setup.err";then
 awk '/(ERROR|FATAL):/{line=$0;sub(/^.*(ERROR|FATAL):[[:space:]]*/,"",line);print "Phase6C setup: "substr(line,1,500);exit}' "$race_dir/setup.err" >&2
 fail setup
fi
profile=$("${psql_cmd[@]}" --command "select id from public.athlete_profiles where participant_id=md5('boss-phase6c-race-base:participant-child1')::uuid");showcase=$("${psql_cmd[@]}" --command "select id from public.recruiting_showcases where profile_id='$profile'");guardian=$("${psql_cmd[@]}" --command "select id from public.guardian_relationships where dependent_person_id=md5('boss-phase6c-race-base:child1')::uuid");share=$("${psql_cmd[@]}" --command "select id from public.recruiting_share_links where showcase_id='$showcase'limit 1");membership=$("${psql_cmd[@]}" --command "select id from public.team_memberships where participant_id=md5('boss-phase6c-race-base:participant-child1')::uuid and status='active'limit 1");profile_revision=$("${psql_cmd[@]}" --command "select current_revision_id from public.athlete_profiles where id='$profile'")
[[ -n "$profile" && -n "$showcase" && -n "$share" ]]||fail 'race fixture missing'
# 1. Duplicate creation serializes on participant identity and leaves one profile.
create_input="jsonb_build_object('participant_id',md5('boss-phase6c-race-base:participant-child1')::uuid,'safe_fields',jsonb_build_object('display_name','Synthetic duplicate'))"
race duplicate_profile "$(mutate admin profile.create "$create_input")" "$(mutate admin profile.create "$create_input")" success
assert_sql 'one canonical profile' "select count(*)=1 from public.athlete_profiles where participant_id=md5('boss-phase6c-race-base:participant-child1')::uuid"
# 2. Two revisions with the same expected version cannot both win.
profile_input="jsonb_build_object('profile_id','$profile','expected_version',1,'safe_fields',jsonb_build_object('display_name','Race winner'))"
race two_profile_revisions "$(mutate admin profile.revise "$profile_input")" "$(mutate admin profile.revise "$profile_input")" PT409
# 3. Profile edit and staff verification serialize on the same profile authority fence.
profile_input2="jsonb_build_object('profile_id','$profile','expected_version',2,'safe_fields',jsonb_build_object('display_name','Race edit'))"
measure_input="jsonb_build_object('profile_id','$profile','sport_key','baseball','metric_key','race_speed','value',4.8,'unit','s','measured_on',current_date,'provenance','coach_verified','visibility','profile','organization_id',md5('boss-phase6c-race-base:org')::uuid,'team_id',md5('boss-phase6c-race-base:falcons')::uuid)"
race edit_staff_verification "$(mutate admin profile.revise "$profile_input2")" "$(mutate coach measurable.add "$measure_input")" success
# 4. Showcase revision and publication cannot cross an outdated consent revision.
current_version=$("${psql_cmd[@]}" --command "select version from public.recruiting_showcases where id='$showcase'")
current_profile_revision=$("${psql_cmd[@]}" --command "select current_revision_id from public.athlete_profiles where id='$profile'")
showcase_input="jsonb_build_object('showcase_id','$showcase','expected_version',$current_version,'profile_revision_id','$current_profile_revision','sport_keys',jsonb_build_array('baseball'),'visible_categories',jsonb_build_array('overview'),'stat_metric_keys','[]'::jsonb,'presentation','{}'::jsonb)"
race revise_vs_publish "$(mutate admin showcase.revise "$showcase_input")" "$(mutate admin showcase.publish "jsonb_build_object('showcase_id','$showcase','expected_version',$current_version)")" PT409
# Restore a fresh guardian consent and publish for remaining link races.
current_showcase_revision=$("${psql_cmd[@]}" --command "select current_revision_id from public.recruiting_showcases where id='$showcase'")
current_version=$("${psql_cmd[@]}" --command "select version from public.recruiting_showcases where id='$showcase'")
"${psql_cmd[@]}" --command "begin;$(mutate parent consent.grant "jsonb_build_object('showcase_id','$showcase','showcase_revision_id','$current_showcase_revision','approved_categories',jsonb_build_array('overview'),'expires_at',clock_timestamp()+interval'1 hour')")commit;" >/dev/null
current_version=$("${psql_cmd[@]}" --command "select version from public.recruiting_showcases where id='$showcase'")
"${psql_cmd[@]}" --command "begin;$(mutate parent showcase.publish "jsonb_build_object('showcase_id','$showcase','expected_version',$current_version)")commit;" >/dev/null
# 5. Revocation racing a read can observe the committed-before or snapshot-before state, never post-commit authority.
snapshot_race share_revoke_read "$(mutate parent share.revoke "jsonb_build_object('share_link_id','$share')")" "select public.boss_recruiting_showcase_read(repeat('a',64));" "select public.boss_recruiting_showcase_read(repeat('a',64))->>'available'='false'"
# 6. Current guardian revocation defeats a blocked publish.
current_version=$("${psql_cmd[@]}" --command "select version from public.recruiting_showcases where id='$showcase'")
race guardian_revoke_publish "update public.guardian_relationships set authority_status='inactive'where id='$guardian';" "$(mutate admin showcase.publish "jsonb_build_object('showcase_id','$showcase','expected_version',$current_version)")" PT403
"${psql_cmd[@]}" --command "update public.guardian_relationships set authority_status='active',can_manage_profile=true where id='$guardian'" >/dev/null
# 7. A source refresh is snapshot coherent, and no stale source remains current after commit.
snapshot_race source_refresh_showcase "update public.stat_origin_summaries set is_current=false where person_id=md5('boss-phase6c-race-base:child1')::uuid;" "select public.boss_recruiting_showcase_read(repeat('a',64));" "select not exists(select 1 from public.stat_origin_summaries where person_id=md5('boss-phase6c-race-base:child1')::uuid and is_current)"
# 8. Transfer/relationship end cannot leave staff access after commit.
snapshot_race transfer_staff_read "update public.team_memberships set status='inactive',ends_at=clock_timestamp()where id='$membership';" "begin;$(auth coach)select public.boss_athlete_profile_read('$profile',null);commit;" "select not boss_private.athlete_can_view(md5('boss-phase6c-race-base:coach')::uuid,'$profile')"
printf 'Phase6C coordinated races passed: %s\n' "$race_count"
