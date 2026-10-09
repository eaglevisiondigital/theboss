#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Ranking races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase6B concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase6B race failure: %s\n' "$label" >&2
 # Only this synthetic local runner writes these files. Show the first primary
 # SQLSTATE/message line; exclude SQL bodies, DETAIL and authentication claims.
 if [[ -s "$errors" ]];then awk '
 /(ERROR|FATAL):/ {line=$0;sub(/^.*(ERROR|FATAL):[[:space:]]*/,"",line);print "PostgreSQL: "substr(line,1,500);found=1;exit}
 /No such file or directory|could not open|Permission denied|^psql:.*(error|fatal):/ {print "psql/file: "substr($0,1,500);found=1;exit}
 END {if(!found)print "No primary SQL error recorded; participant log contains no recognized file or SQL failure."}
 ' "$errors" >&2;fi
}
assert_sql(){ if [[ $("${psql_cmd[@]}" --command "$2") != t ]];then fail "$1";fi; }
await_state(){
 local app=$1 expected=$2 pid=$3 errors=$4 deadline=$((SECONDS+7)) query
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase6b-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Ranking race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Ranking race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase6b-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase6b-$label-writer.out" 2>"$race_dir/phase6b-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase6b_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase6b-writer-ready */;" >&9
 await_state "boss_phase6b_${label}_writer" ready "$writer_pid" "$race_dir/phase6b-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase6b_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase6b-$label-contender.out" 2>"$race_dir/phase6b-$label-contender.err" & contender_pid=$!
 await_state "boss_phase6b_${label}_contender" waiting "$contender_pid" "$race_dir/phase6b-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase6b-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase6b-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase6b-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase6b-$label-contender.err";fail "$label expected $expected";fi
race_count=$((race_count+1))
}

# Distinct synthetic namespace prevents collision with prior historical races.
sed -e 's/boss-phase5a-test:/boss-phase6b-race-base:/g' -e 's/phase5a.example.invalid/phase6b-race.example.invalid/g' -e 's/synthetic-phase5a-/synthetic-phase6b-race-/g' "$test_dir/phase5a/fixture.sql" >"$race_dir/phase6b-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5d-test:/,"boss-phase6b-race-roster:");print}' "$test_dir/phase5d/fixture.sql" >>"$race_dir/phase6b-fixture.sql"
awk '$0!="\\ir ../phase5d/fixture.sql" {print}' "$test_dir/phase5f/fixture.sql" >>"$race_dir/phase6b-fixture.sql"
awk '$0!="\\ir ../phase5f/fixture.sql" {print}' "$test_dir/phase6b/fixture.sql" >>"$race_dir/phase6b-fixture.sql"
cat >>"$race_dir/phase6b-fixture.sql" <<'SQL'
create function pg_temp.record_game(label text,primary_homers int,opponent_homers int)returns void language plpgsql as $$declare half int;hits int;i int;begin
 perform pg_temp.dd_create(label,'baseball','essential');
 perform public.boss_stat_competition_classify(pg_temp.ff_game(label),'official','Synthetic chronological record source',gen_random_uuid());
 for half in 1..2 loop
 hits:=case half when 1 then primary_homers else opponent_homers end;
 if hits>0 then
 perform pg_temp.dd_pa(label,label||'-hr1-'||half);perform pg_temp.dd_play(label,'home_run',jsonb_build_array(pg_temp.dd_move(0,4)));
 if hits=2 then for i in 1..3 loop
 perform pg_temp.dd_pa(label,label||'-walk-'||half||'-'||i);perform pg_temp.dd_play(label,'walk',(select jsonb_agg(pg_temp.dd_move(n,n+1,'walk')order by n desc)from generate_series(0,i-1)n));end loop;
 perform pg_temp.dd_pa(label,label||'-hr2-'||half);perform pg_temp.dd_play(label,'home_run',jsonb_build_array(pg_temp.dd_move(3,4),pg_temp.dd_move(2,4),pg_temp.dd_move(1,4),pg_temp.dd_move(0,4)));end if;
 end if;
 for i in 1..3 loop perform pg_temp.dd_pa(label,label||'-out-'||half||'-'||i);perform pg_temp.dd_play(label,'other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;
 if half=1 then perform pg_temp.dd_op('diamond.half.start',label,'{"payload":{"kind":"half_start"}}');end if;
 end loop;
 perform pg_temp.game_op('game.finalize',label);
 perform pg_temp.rb('game.assign',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'game_id',pg_temp.ff_game(label),'primary_entry_id',pg_temp.rb_id('falcons-entry'),'opponent_entry_id',pg_temp.rb_id('wildcats-entry'),'game_type','league','counts_for_standings',true,'reason','Synthetic chronological record assignment'));
end$$;
revoke all on function pg_temp.record_game(text,int,int)from public;grant execute on function pg_temp.record_game(text,int,int)to authenticated;
SQL
cat >"$race_dir/phase6b-setup.sql" <<SQL
begin;set local statement_timeout='8s';
\ir '$race_dir/phase6b-fixture.sql'
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'),'season_id',pg_temp.f('season'),'product','leaderboard','source_kind','athlete_season','name','Synthetic race board','metric_key','home_runs','metric_kind','count','direction','high','qualification','{}'::jsonb),'board');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'),'season_id',pg_temp.f('season'),'product','records','source_kind','athlete_season','name','Synthetic race record','metric_key','home_runs','metric_kind','count','direction','high','qualification','{}'::jsonb),'record');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q(),'standing');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','board'));
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('records','record'));
select pg_temp.rb('access.grant',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'person_id',pg_temp.f('household-only'),'ends_at',clock_timestamp()+interval'1 hour'),'manager');
select pg_temp.record_game('race-second-game',1,0);
reset role;commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase6b-setup.sql" >"$race_dir/phase6b-setup.out" 2>"$race_dir/phase6b-setup.err";then diagnostics setup "$race_dir/phase6b-setup.err";fail setup;fi
ed=$("${psql_cmd[@]}" --command "select id from public.competition_editions where name='Synthetic Phase 6B Edition'")
gid=$("${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase6b-race-base:event-ff-ranking-game')::uuid")
board=$("${psql_cmd[@]}" --command "select id from public.ranking_definitions where name='Synthetic race board'")
record=$("${psql_cmd[@]}" --command "select id from public.ranking_definitions where name='Synthetic race record'")
standing=$("${psql_cmd[@]}" --command "select id from public.ranking_scopes where edition_id='$ed'and product='standings'")
bscope=$("${psql_cmd[@]}" --command "select id from public.ranking_scopes where definition_id='$board'")
rscope=$("${psql_cmd[@]}" --command "select id from public.ranking_scopes where definition_id='$record'")
entry=$("${psql_cmd[@]}" --command "select id from public.competition_entries where edition_id='$ed'and team_id=md5('boss-phase6b-race-base:falcons')::uuid")
manager=$("${psql_cmd[@]}" --command "select id from public.competition_access_assignments where edition_id='$ed'")
gid2=$("${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase6b-race-base:event-ff-race-second-game')::uuid")
[[ -n "$gid" && -n "$ed" && -n "$rscope" ]] || fail 'canonical race fixture missing'
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase6b-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase6b-race-base:session-$1')::uuid)::text,true);"; }
command(){ printf '%s' "reset role;select set_config('boss.phase6b_test_version',(select version::text from public.games where id='$gid'),true);$(auth admin)select public.boss_games_mutate(gen_random_uuid(),jsonb_build_object('operation','$1','input',jsonb_build_object('game_id','$gid','expected_version',current_setting('boss.phase6b_test_version')::bigint)||case when '$1'='game.reopen'then jsonb_build_object('reason','Synthetic ranking concurrency')else '{}'::jsonb end));reset role;"; }
flush="set constraints public.ranking_stat_source_changed immediate;set constraints public.ranking_stat_source_changed deferred;"
refresh="select boss_private.ranking_refresh('$standing');"
brefresh="select boss_private.ranking_refresh('$bscope');"
rrefresh="select boss_private.ranking_refresh('$rscope');"
"${psql_cmd[@]}" --command "begin;$(command game.reopen)commit;" >"$race_dir/phase6b-open.out"
race finalization_standings "$(command game.finalize)$flush" "$refresh" success
assert_sql 'one final game exactly once' "select count(*)=2 and sum(games_played)=4 from public.standings_rows where scope_id='$standing'"
race refinalization_standings "$(command game.reopen)$(command game.finalize)$flush" "$refresh" success
assert_sql 'new epoch does not duplicate game' "select sum(games_played)=4 from public.standings_rows where scope_id='$standing'"
race two_standings_workers "$refresh" "$refresh" success
policy="jsonb_build_object('template','baseball','order_by','wins','tie_weight',0.5,'allow_ties',true,'tiebreaks','[]'::jsonb)"
race policy_refresh "$(auth admin)select public.boss_ranking_mutate(jsonb_build_object('action','policy.activate','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','configuration',$policy,'reason','Synthetic policy race')));reset role;" "$refresh" success
assert_sql 'published standings matches new policy generation' "select state='current'and published_generation=(select generation from public.competition_editions where id='$ed')from public.ranking_scopes where id='$standing'"
race entry_end_read "$(auth admin)select public.boss_ranking_mutate(jsonb_build_object('action','entry.end','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','entry_id','$entry')));reset role;" "$(auth parent)select public.boss_ranking_read(jsonb_build_object('edition_id','$ed','product','standings'));" PT403
"${psql_cmd[@]}" --command "update public.competition_entries set status='active',ended_at=null,version=version+1 where id='$entry'" >"$race_dir/phase6b-entry-restored.out"
race source_generation_leaderboard "$(command game.reopen)$(command game.finalize)$flush" "$brefresh" success
assert_sql 'leaderboard canonical new epoch value' "select max(value)=2 and count(*)filter(where rank=1)=1 from public.ranking_candidates where scope_id='$bscope'"
race qualification_replacement "$(auth admin)select public.boss_ranking_mutate(jsonb_build_object('action','definition.end','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','definition_id','$board')));reset role;" "$(auth admin)select public.boss_ranking_mutate(jsonb_build_object('action','ranking.rebuild','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id','$ed','product','leaderboard','definition_id','$board')));" PT403
"${psql_cmd[@]}" --command "update public.ranking_definitions set status='active',version=version+1 where id='$board'" >"$race_dir/phase6b-definition-restored.out"
# Two independent native finalizations contend at the edition fence. No worker
# holds that fence while acquiring the other game's canonical source lock.
"${psql_cmd[@]}" --command "begin;$(command game.reopen)commit;" >"$race_dir/phase6b-first-reopen.out"
gid_first=$gid;gid=$gid2
"${psql_cmd[@]}" --command "begin;$(command game.reopen)commit;" >"$race_dir/phase6b-second-reopen.out"
second_finalize="$(command game.finalize)";gid=$gid_first
race two_record_source_games "$(command game.finalize)$flush" "$second_finalize" success
"${psql_cmd[@]}" --command "$rrefresh" >"$race_dir/phase6b-two-games-record.out"
assert_sql 'both independent finalizations recognized once' "select count(*)=1 and min(ev.value)=2 from public.record_current_holders h join public.record_events ev on ev.id=h.event_id where h.definition_id='$record'"
race correction_record_recognition "$(command game.reopen)$(auth admin)select public.boss_stat_competition_classify('$gid','excluded','Synthetic corrected record eligibility',gen_random_uuid());$(command game.finalize)$flush" "$rrefresh" success
assert_sql 'correction cannot leave an orphan current record' "select(select count(*)=1 and min(ev.value)=1 from public.record_current_holders h join public.record_events ev on ev.id=h.event_id where h.definition_id='$record')and exists(select 1 from public.record_events where definition_id='$record'and event_type='invalidated_by_source_correction')"
"${psql_cmd[@]}" --command "begin;$(command game.reopen)$(auth admin)select public.boss_stat_competition_classify('$gid','official','Synthetic restored record eligibility',gen_random_uuid());$(command game.finalize)commit;" >"$race_dir/phase6b-record-restored.out"
race two_record_workers "$rrefresh" "$rrefresh" success
assert_sql 'two workers preserve one current record' "select count(*)=1 from public.record_current_holders where definition_id='$record'"
race authority_revoked_read "update public.competition_access_assignments set status='inactive'where id='$manager';" "$(auth household-only)select public.boss_ranking_read(jsonb_build_object('edition_id','$ed','product','standings'));" PT403
"${psql_cmd[@]}" --command "update public.competition_access_assignments set status='active',ends_at=clock_timestamp()+interval'1 hour'where id='$manager'" >"$race_dir/phase6b-manager-restored.out"
race authority_expired_read "update public.competition_access_assignments set ends_at=clock_timestamp()+interval'800 milliseconds'where id='$manager';" "$(auth household-only)select public.boss_ranking_read(jsonb_build_object('edition_id','$ed','product','standings'));" PT403 1.1
"${psql_cmd[@]}" --command "update public.competition_access_assignments set status='active',ends_at=clock_timestamp()+interval'1 hour'where id='$manager'" >"$race_dir/phase6b-manager-reset.out"
race repeatable_read_revocation "update public.competition_access_assignments set status='inactive'where id='$manager';" "set transaction isolation level repeatable read;$(auth household-only)select public.boss_ranking_read(jsonb_build_object('edition_id','$ed','product','standings'));" 40001
printf 'Phase6B coordinated races passed: %s\n' "$race_count"
