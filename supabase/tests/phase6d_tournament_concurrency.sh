#!/usr/bin/env bash
# Real two-connection tournament races on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Tournament races require the disposable private socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
fail(){ printf 'Phase6D concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
auth="set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5a-test:auth-admin')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5a-test:session-admin')::uuid)::text,true);"
cat >"$race_dir/phase6d-setup.sql" <<SQL
begin;set local statement_timeout='8s';
\ir '$test_dir/phase6d/fixture.sql'
select pg_temp.rb_id('edition') ed,pg_temp.td_id('bracket') seeded_bracket,(select id from public.tournament_matches where bracket_id=pg_temp.td_id('bracket')and round_number=1 and match_number=1) match_one,(select id from pg_temp.phase5a_games where label='tournament-first') game_one \gset
$auth
select(public.boss_tournament_mutate(jsonb_build_object('action','bracket.create','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',:'ed','name','Synthetic concurrency seed bracket','bracket_size',4)))->>'id')seed_race_bracket \gset
reset role;
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase6d-setup.sql" >"$race_dir/phase6d-setup.out" 2>"$race_dir/phase6d-setup.err";then sed -n '/ERROR:/p' "$race_dir/phase6d-setup.err" >&2;fail setup;fi
ed=$("${psql_cmd[@]}" --command "select id from public.competition_editions where name='Synthetic Phase 6B Edition'")
seed_bracket=$("${psql_cmd[@]}" --command "select id from public.tournament_brackets where name='Synthetic concurrency seed bracket'")
match_one=$("${psql_cmd[@]}" --command "select tm.id from public.tournament_matches tm join public.tournament_brackets b on b.id=tm.bracket_id where b.name='Synthetic Phase 6D Bracket'and tm.round_number=1 and tm.match_number=1")
match_two=$("${psql_cmd[@]}" --command "select tm.id from public.tournament_matches tm join public.tournament_brackets b on b.id=tm.bracket_id where b.name='Synthetic Phase 6D Bracket'and tm.round_number=1 and tm.match_number=2")
game_one=$("${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase5a-test:event-neutral')::uuid")
falcons=$("${psql_cmd[@]}" --command "select id from public.competition_entries where edition_id='$ed'and team_id=md5('boss-phase5a-test:falcons')::uuid")
wildcats=$("${psql_cmd[@]}" --command "select id from public.competition_entries where edition_id='$ed'and team_id=md5('boss-phase5a-test:wildcats')::uuid")
hawks=$("${psql_cmd[@]}" --command "select id from public.competition_entries where edition_id='$ed'and team_id=md5('boss-phase5a-test:hawks')::uuid")
eagles=$("${psql_cmd[@]}" --command "select id from public.competition_entries where edition_id='$ed'and team_id=md5('boss-phase5a-test:eagles')::uuid")
[[ -n "$ed" && -n "$seed_bracket" && -n "$match_one" && -n "$match_two" && -n "$game_one" ]]||fail 'race fixture identifiers'
run_race(){ local label=$1 command=$2 expected=$3;local writer="$race_dir/phase6d-$label-writer" contender="$race_dir/phase6d-$label-contender";("${psql_cmd[@]}" --command "set statement_timeout='8s';begin;$auth $command select pg_sleep(0.35);commit;" >"$writer.out" 2>"$writer.err")&local writer_pid=$!;sleep 0.08;local rc=0;if "${psql_cmd[@]}" --command "set statement_timeout='8s';begin;$auth $command commit;" >"$contender.out" 2>"$contender.err";then rc=0;else rc=$?;fi;wait "$writer_pid"||{ sed -n '/ERROR:/p' "$writer.err" >&2;fail "$label writer";};if [[ "$expected" == success && "$rc" != 0 ]];then sed -n '/ERROR:/p' "$contender.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$contender.err";};then sed -n '/ERROR:/p' "$contender.err" >&2;fail "$label expected $expected";fi;}
schedule_command="select public.boss_tournament_mutate(jsonb_build_object('action','match.link_game','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','match_id','$match_one','expected_version',1,'game_id','$game_one')));"
run_race schedule_same_match "$schedule_command" PT409
[[ $("${psql_cmd[@]}" --command "select game_id='$game_one'::uuid and version=2 from public.tournament_matches where id='$match_one'") == t ]]||fail 'one canonical game link'
finalization_result_command="select public.boss_tournament_mutate(jsonb_build_object('action','result.process','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','match_id','$match_one','expected_version',2,'reason','Disposable finalization versus advancement')));"
("${psql_cmd[@]}" --command "begin;update public.games set status='final',roster_revision=1,started_at=clock_timestamp()-interval'2 hours',finalized_at=clock_timestamp(),finalized_by_person_id=md5('boss-phase5a-test:admin')::uuid,winner_side='primary',tied=false,primary_score=2,opponent_score=0,final_primary_score=2,final_opponent_score=0,finalization_count=1 where id='$game_one';select pg_sleep(0.35);commit;" >"$race_dir/phase6d-finalizer.out" 2>"$race_dir/phase6d-finalizer.err")&finalizer_pid=$!
sleep 0.08
if ! "${psql_cmd[@]}" --command "begin;$auth $finalization_result_command commit;" >"$race_dir/phase6d-finalization-advancement.out" 2>"$race_dir/phase6d-finalization-advancement.err";then sed -n '/ERROR:/p' "$race_dir/phase6d-finalization-advancement.err" >&2;fail 'finalization versus advancement';fi
wait "$finalizer_pid"||fail 'canonical finalizer'
[[ $("${psql_cmd[@]}" --command "select count(*)=1 from public.tournament_advancements where source_match_id='$match_one'") == t ]]||fail 'one official-result advancement epoch'
result_command="select public.boss_tournament_mutate(jsonb_build_object('action','result.process','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','match_id','$match_one','expected_version',3,'reason','Disposable duplicate official result')));"
run_race duplicate_result "$result_command" success
[[ $("${psql_cmd[@]}" --command "select count(*)=1 from public.tournament_advancements where source_match_id='$match_one'") == t ]]||fail 'duplicate processing remains idempotent'
"${psql_cmd[@]}" --command "update public.games set winner_side='opponent',primary_score=1,opponent_score=3,final_primary_score=1,final_opponent_score=3,finalization_count=2 where id='$game_one'" >/dev/null
correction_command="select public.boss_tournament_mutate(jsonb_build_object('action','result.process','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','match_id','$match_one','expected_version',3,'reason','Disposable concurrent corrected result')));"
run_race correction_advancement "$correction_command" PT409
[[ $("${psql_cmd[@]}" --command "select count(*)=2 and max(generation)=2 from public.tournament_advancements where source_match_id='$match_one'") == t ]]||fail 'one corrected advancement epoch'
ruling_command="select public.boss_tournament_mutate(jsonb_build_object('action','ruling.create','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','match_id','$match_two','expected_version',1,'kind','forfeit','winner_entry_id','$hawks','loser_entry_id','$eagles','reason','Disposable concurrent ruling')));"
run_race ruling_automatic_boundary "$ruling_command" PT409
[[ $("${psql_cmd[@]}" --command "select count(*)=1 from public.tournament_advancements where source_match_id='$match_two'") == t ]]||fail 'one ruling advancement'
seeds="jsonb_build_array(jsonb_build_object('seed',1,'entry_id','$falcons'),jsonb_build_object('seed',2,'entry_id','$hawks'),jsonb_build_object('seed',3,'entry_id','$eagles'),jsonb_build_object('seed',4,'entry_id','$wildcats'))"
seed_command="select public.boss_tournament_mutate(jsonb_build_object('action','bracket.seed','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','bracket_id','$seed_bracket','expected_version',1,'source_kind','manual','seeds',$seeds,'reason','Disposable concurrent seed acceptance')));"
run_race seed_version "$seed_command" PT409
[[ $("${psql_cmd[@]}" --command "select current_revision=1 and version=2 from public.tournament_brackets where id='$seed_bracket'") == t ]]||fail 'one accepted seed revision'
rebuild_command="select public.boss_tournament_mutate(jsonb_build_object('action','projection.rebuild','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','bracket_id','$seed_bracket','expected_version',2)));"
run_race rebuild_projection "$rebuild_command" success
[[ $("${psql_cmd[@]}" --command "select current_revision=1 and version=2 from public.tournament_brackets where id='$seed_bracket'") == t ]]||fail 'rebuild preserves canonical revision'
archive_command="select public.boss_tournament_mutate(jsonb_build_object('action','bracket.archive','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','bracket_id','$seed_bracket','expected_version',2)));"
run_race archive_version "$archive_command" PT409
[[ $("${psql_cmd[@]}" --command "select status='archived'and version=3 from public.tournament_brackets where id='$seed_bracket'") == t ]]||fail 'one archive transition'
create_request=$("${psql_cmd[@]}" --command "select md5('phase6d-concurrent-create-request')::uuid")
create_command="select public.boss_tournament_mutate(jsonb_build_object('action','bracket.create','request_id','$create_request','input',jsonb_build_object('edition_id','$ed','name','Synthetic idempotent concurrent bracket','bracket_size',2)));"
run_race bracket_generation "$create_command" success
[[ $("${psql_cmd[@]}" --command "select count(*)=1 from public.tournament_brackets where name='Synthetic idempotent concurrent bracket'") == t ]]||fail 'one idempotent concurrent bracket creation'

# A blocked manager mutation must recheck authority after acquiring the row
# lock. The manager is revoked while waiting and must not seed the bracket.
"${psql_cmd[@]}" --command "begin;$auth select public.boss_ranking_mutate(jsonb_build_object('action','access.grant','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','person_id',md5('boss-phase5a-test:household-only')::uuid,'ends_at',clock_timestamp()+interval'10 minutes')));select public.boss_tournament_mutate(jsonb_build_object('action','bracket.create','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','name','Synthetic authority race bracket','bracket_size',2)));commit;" >/dev/null
authority_bracket=$("${psql_cmd[@]}" --command "select id from public.tournament_brackets where name='Synthetic authority race bracket'")
authority_assignment=$("${psql_cmd[@]}" --command "select id from public.competition_access_assignments where edition_id='$ed'and person_id=md5('boss-phase5a-test:household-only')::uuid and status='active'order by created_at desc limit 1")
manager_auth="set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5a-test:auth-household-only')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5a-test:session-household-only')::uuid)::text,true);"
(PGAPPNAME=phase6d-lock-holder "${psql_cmd[@]}" --command "begin;select id from public.tournament_brackets where id='$authority_bracket'for update;select pg_sleep(0.7);commit;" >"$race_dir/phase6d-authority-lock.out" 2>"$race_dir/phase6d-authority-lock.err")&lock_pid=$!
sleep 0.08
(PGAPPNAME=phase6d-authority-contender "${psql_cmd[@]}" --command "begin;$manager_auth select public.boss_tournament_mutate(jsonb_build_object('action','bracket.seed','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','bracket_id','$authority_bracket','expected_version',1,'source_kind','manual','seeds',jsonb_build_array(jsonb_build_object('seed',1,'entry_id','$falcons'),jsonb_build_object('seed',2,'entry_id','$wildcats')),'reason','Must be denied after blocked revocation')));commit;" >"$race_dir/phase6d-authority-contender.out" 2>"$race_dir/phase6d-authority-contender.err")&manager_pid=$!
blocked=false
for _ in {1..20};do if [[ $("${psql_cmd[@]}" --command "select exists(select 1 from pg_stat_activity where application_name='phase6d-authority-contender'and wait_event_type='Lock')") == t ]];then blocked=true;break;fi;sleep 0.02;done
[[ "$blocked" == true ]]||fail 'authority contender did not block on canonical row'
"${psql_cmd[@]}" --command "begin;$auth select public.boss_ranking_mutate(jsonb_build_object('action','access.end','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','assignment_id','$authority_assignment')));commit;" >/dev/null
wait "$lock_pid"||fail 'authority lock holder'
manager_rc=0;wait "$manager_pid"||manager_rc=$?
[[ "$manager_rc" != 0 ]]&&grep -Fq 'PT403' "$race_dir/phase6d-authority-contender.err"||fail 'blocked mutation did not recheck revoked authority'
[[ $("${psql_cmd[@]}" --command "select current_revision=0 and version=1 from public.tournament_brackets where id='$authority_bracket'") == t ]]||fail 'revoked manager changed bracket'
printf '%s\n' 'Phase6D coordinated races passed: 10'
