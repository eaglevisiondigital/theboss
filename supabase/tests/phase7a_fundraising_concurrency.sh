#!/usr/bin/env bash
# Real two-connection Phase 7A transaction races on the private disposable socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Phase7A races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase7A concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
assert_sql(){ [[ $("${psql_cmd[@]}" --command "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%phase7a-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $("${psql_cmd[@]}" --command "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4;local fifo="$race_dir/phase7a-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/$label-w.out" 2>"$race_dir/$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase7a_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase7a-writer-ready */;" >&9;await_state "boss_phase7a_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_phase7a_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/$label-c.out" 2>"$race_dir/$label-c.err"&contender_pid=$!;await_state "boss_phase7a_${label}_contender" waiting "$contender_pid"||fail "$label contender did not block";printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||fail "$label writer";writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/$label-c.err";};then fail "$label expected $expected";fi;race_count=$((race_count+1)); }
snapshot_race(){ local label=$1 writer_sql=$2 read_sql=$3 post_assert=$4;local fifo="$race_dir/phase7a-$label.stdin";mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/$label-w.out" 2>"$race_dir/$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase7a_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase7a-writer-ready */;" >&9;await_state "boss_phase7a_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set statement_timeout='8s';$read_sql" >"$race_dir/$label-read.out" 2>"$race_dir/$label-read.err"||fail "$label snapshot read";printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||fail "$label writer";writer_pid='';assert_sql "$label post-commit" "$post_assert";race_count=$((race_count+1)); }
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase7a-race:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase7a-race:session-$1')::uuid)::text,true);"; }
mutate(){ printf '%s' "$(auth "$1")select public.boss_fundraising_mutate(jsonb_build_object('action','$2','request_id',gen_random_uuid(),'input',$3));reset role;"; }
# Use independent synthetic identities, no network and no real credentials.
sed -e 's/boss-phase7a-test:/boss-phase7a-race:/g' -e 's/phase7a.example.invalid/phase7a-race.example.invalid/g' -e 's/synthetic-phase7a-/synthetic-phase7a-race-/g' "$test_dir/phase7a/fixture.sql" >"$race_dir/phase7a-fixture.sql"
printf '%s\n' 'begin;' "\\ir '$race_dir/phase7a-fixture.sql'" 'commit;' >"$race_dir/phase7a-setup.sql"
if ! "${psql_cmd[@]}" --file "$race_dir/phase7a-setup.sql" >"$race_dir/setup7a.out" 2>"$race_dir/setup7a.err";then head -n 6 "$race_dir/setup7a.err" >&2;fail setup;fi
lookup(){ "${psql_cmd[@]}" --command "$1"; }
org="md5('boss-phase7a-race:org')::uuid";child="md5('boss-phase7a-race:child1')::uuid";admin="md5('boss-phase7a-race:admin')::uuid"
campaign=$(lookup "select id from public.fundraising_campaigns where organization_id=$org")
fundraiser=$(lookup "select id from public.fundraising_fundraisers where campaign_id='$campaign'")
board=$(lookup "select id from public.money_boards where campaign_id='$campaign'")
path=$(lookup "select path from public.fundraising_shares where fundraiser_id='$fundraiser'and status='active'")
guardian="md5('boss-phase7a-race:guardian-child1')::uuid"
guest(){ printf '%s' "set local role anon;select public.boss_fundraising_support(jsonb_build_object('action','$1','request_id','$3','input',jsonb_build_object('path','$path','capability',repeat('$4',64))||$2));reset role;"; }
new_request(){ lookup 'select gen_random_uuid()'; }
reserve(){ guest reserve "jsonb_build_object('ordinal',$1)" "$(new_request)" "$2"; }
intent(){ guest intent "jsonb_build_object('amount_minor',$1,'display_name','Synthetic race donor','months',6)" "$2" "$3"; }
# 1 Same tile: observed real lock wait, exactly one accepted reservation.
race same_tile "$(reserve 1 a)" "$(reserve 1 b)" PT409
assert_sql 'single winner' "select count(*)=1 from public.money_board_reservations r join public.money_board_tiles t on t.id=r.tile_id where t.board_id='$board'and t.ordinal=1"
# 2 Natural expiry while contender waits: current clock prevents extension.
"${psql_cmd[@]}" --command "update public.money_board_reservations set expires_at=starts_at+interval'1 second'where tile_id in(select id from public.money_board_tiles where board_id='$board'and ordinal=1)" >/dev/null
race expiry_reserve "select id from public.fundraising_campaigns where id='$campaign'for update;select pg_sleep(1.1);" "$(reserve 1 c)" success
assert_sql 'expired history plus new reservation' "select count(*)=2 from public.money_board_reservations r join public.money_board_tiles t on t.id=r.tile_id where t.board_id='$board'and t.ordinal=1"
# 3 Pausing wins before a blocked donor intent.
race pause_intent "update public.fundraising_campaigns set status='paused'where id='$campaign';" "$(intent 100 "$(new_request)" d)" PT404
"${psql_cmd[@]}" --command "update public.fundraising_campaigns set status='active'where id='$campaign'" >/dev/null
# 4 Ending campaign participation denies stale canonical attribution.
race end_intent "select id from public.fundraising_campaigns where id='$campaign'for update;update public.fundraising_fundraisers set status='ended'where id='$fundraiser';" "$(intent 100 "$(new_request)" e)" PT404
"${psql_cmd[@]}" --command "update public.fundraising_fundraisers set status='active'where id='$fundraiser';update public.money_board_reservations set released_at=clock_timestamp(),release_reason='supporter_cancel'where tile_id in(select id from public.money_board_tiles where board_id='$board')" >/dev/null
# 5 Regeneration unpublishes the board before a waiting supporter can reserve.
race regenerate_reserve "$(mutate admin board.generate "jsonb_build_object('campaign_id','$campaign','board_id','$board','expected_version',3)")" "$(reserve 2 f)" PT404
"${psql_cmd[@]}" --command "update public.money_boards set status='published'where id='$board'" >/dev/null
# 6 A real success replay retains a single canonical evidence/reward row.
req=$(new_request);"${psql_cmd[@]}" --command "begin;$(intent 2501 "$req" 1)commit;" >/dev/null
paid=$(lookup "select id from public.fundraising_intents where request_id='$req'");settled=$(lookup "select created_at+interval'1 microsecond'from public.fundraising_intents where id='$paid'")
ingest="select boss_private.fundraising_ingest_success('$paid','disposable_race','same-source',2501,'USD','$settled');"
race trusted_replay "$ingest" "$ingest" success
assert_sql 'one evidence' "select count(*)=1 from public.fundraising_success_evidence where intent_id='$paid'"
assert_sql 'one gift' "select count(*)=1 and bool_and(qualified)from public.fundraising_reward_qualifications where evidence_id=(select id from public.fundraising_success_evidence where intent_id='$paid')"
# 7 Guest retry creates only one commitment and six planned occurrences.
req=$(new_request);cmd=$(intent 100 "$req" 2)
race recurring_retry "$cmd" "$cmd" success
assert_sql 'one recurring schedule' "select count(*)=6 from public.fundraising_recurring_occurrences o join public.fundraising_recurring_commitments c on c.id=o.commitment_id join public.fundraising_intents i on i.id=c.intent_id where i.request_id='$req'"
# 8 Same external source cannot reward a different contribution a second time.
req=$(new_request);"${psql_cmd[@]}" --command "begin;$(intent 2501 "$req" 3)commit;" >/dev/null
paid2=$(lookup "select id from public.fundraising_intents where request_id='$req'");settled2=$(lookup "select created_at+interval'1 microsecond'from public.fundraising_intents where id='$paid2'")
race source_reuse "$ingest" "select boss_private.fundraising_ingest_success('$paid2','disposable_race','same-source',2501,'USD','$settled2');" 23505
# 9 Revocation before a blocked guardian share save is enforced after the wait.
race guardian_revoke "update public.guardian_relationships set can_manage_fundraising=false where id=$guardian;" "$(mutate parent share.reset "jsonb_build_object('campaign_id','$campaign','fundraiser_id','$fundraiser')")" PT403
"${psql_cmd[@]}" --command "update public.guardian_relationships set can_manage_fundraising=true where id=$guardian" >/dev/null
# 10 Role removal wins before a blocked campaign mutation.
race role_revoke "update public.role_assignments set status='inactive'where id=md5('boss-phase7a-race:role-admin')::uuid;" "$(mutate admin campaign.status "jsonb_build_object('campaign_id','$campaign','expected_version',2,'status','paused')")" PT403
"${psql_cmd[@]}" --command "update public.role_assignments set status='active'where id=md5('boss-phase7a-race:role-admin')::uuid" >/dev/null
# Trusted ingestion also rechecks canonical relationship/module after a lock wait.
req=$(new_request);"${psql_cmd[@]}" --command "begin;$(intent 2501 "$req" 5)commit;" >/dev/null
pending=$(lookup "select id from public.fundraising_intents where request_id='$req'");pending_at=$(lookup "select created_at+interval'1 microsecond'from public.fundraising_intents where id='$pending'")
pending_ingest="select boss_private.fundraising_ingest_success('$pending','disposable_race','post-lock-check',2501,'USD','$pending_at');"
race trusted_participant_end "update public.fundraising_fundraisers set status='ended'where id='$fundraiser';" "$pending_ingest" PT409
"${psql_cmd[@]}" --command "update public.fundraising_fundraisers set status='active'where id='$fundraiser'" >/dev/null
race trusted_module_end "update public.organization_modules set status='inactive'where organization_id=$org and module_id=(select id from public.modules where key='fundraising');" "$pending_ingest" PT409
assert_sql 'blocked trusted ingestion creates no value' "select not exists(select 1 from public.fundraising_success_evidence where intent_id='$pending')"
"${psql_cmd[@]}" --command "update public.organization_modules set status='active'where organization_id=$org and module_id=(select id from public.modules where key='fundraising')" >/dev/null
# 11 Module removal wins before a blocked supporter reservation.
race module_revoke "update public.organization_modules set status='inactive'where organization_id=$org and module_id=(select id from public.modules where key='fundraising');" "$(reserve 4 4)" PT404
printf 'Phase7A coordinated races passed: %s\n' "$race_count"
