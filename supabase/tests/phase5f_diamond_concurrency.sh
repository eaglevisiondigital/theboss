#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Diamond races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase5F concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase5F race failure: %s\n' "$label" >&2
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
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase5f-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Diamond race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Diamond race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase5f-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase5f-$label-writer.out" 2>"$race_dir/phase5f-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase5f_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase5f-writer-ready */;" >&9
 await_state "boss_phase5f_${label}_writer" ready "$writer_pid" "$race_dir/phase5f-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase5f_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase5f-$label-contender.out" 2>"$race_dir/phase5f-$label-contender.err" & contender_pid=$!
 await_state "boss_phase5f_${label}_contender" waiting "$contender_pid" "$race_dir/phase5f-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase5f-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase5f-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase5f-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase5f-$label-contender.err";fail "$label expected $expected";fi
race_count=$((race_count+1))
}
# Distinct committed synthetic fixture namespace; guarded private socket only.
sed -e 's/boss-phase5a-test:/boss-phase5f-race-base:/g' -e 's/phase5a.example.invalid/phase5f-race.example.invalid/g' -e 's/synthetic-phase5a-/synthetic-phase5f-race-/g' "$test_dir/phase5a/fixture.sql" >"$race_dir/phase5f-race-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5d-test:/,"boss-phase5f-race-roster:");print}' "$test_dir/phase5d/fixture.sql" >>"$race_dir/phase5f-race-fixture.sql"
awk '$0!="\\ir ../phase5d/fixture.sql" {print}' "$test_dir/phase5f/fixture.sql" >>"$race_dir/phase5f-race-fixture.sql"
cat >"$race_dir/phase5f-race-setup.sql" <<SQL
begin;
\ir '$race_dir/phase5f-race-fixture.sql'
set local role authenticated;select pg_temp.actor('admin');
do \$\$declare label text;half int;i int;begin
foreach label in array array['pitch','pitchpa','pa','runner','third','final','scorefinal','pitcher','sub','correction','authority','profile','duplicate']loop
 perform pg_temp.dd_create(label,'baseball',case when label in('pitch','pitchpa','profile','duplicate','pitcher')then'full'else'essential'end);
 if label in('runner','correction')then
 perform pg_temp.dd_pa(label,label||'-first');perform pg_temp.dd_play(label,'single',jsonb_build_array(pg_temp.dd_move(0,1)));end if;
 if label in('third','scorefinal')then
 for i in 1..2 loop perform pg_temp.dd_pa(label,label||'-out'||i);perform pg_temp.dd_play(label,'other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;end if;
 if label='final'then
 perform pg_temp.dd_pa(label,label||'-hr');perform pg_temp.dd_play(label,'home_run',jsonb_build_array(pg_temp.dd_move(0,4)));
 for half in 1..2 loop
 for i in 1..3 loop perform pg_temp.dd_pa(label,label||'-half'||half||'-out'||i);perform pg_temp.dd_play(label,'other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;
 if half=1 then perform pg_temp.dd_op('diamond.half.start',label,'{"payload":{"kind":"half_start"}}');end if;end loop;
 elsif label not in('sub','pitcher')then perform pg_temp.dd_pa(label,label||'-pa');end if;
end loop;
perform pg_temp.game_op('game.operator.assign','authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',clock_timestamp()+interval '1 hour'));
end\$\$;
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase5f-race-setup.sql" >"$race_dir/phase5f-race-setup.out" 2>"$race_dir/phase5f-race-setup.err";then diagnostics setup "$race_dir/phase5f-race-setup.err";fail 'fixture setup';fi
uuid(){ "${psql_cmd[@]}" --command "select md5('boss-phase5f-race-base:$1')::uuid"; }
game_id(){ "${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase5f-race-base:event-ff-$1')::uuid"; }
version(){ "${psql_cmd[@]}" --command "select version from public.games where id='$(game_id "$1")'"; }
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5f-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5f-race-base:session-$1')::uuid)::text,true);"; }
command(){ local op=$1 label=$2 extra=$3 request=$4 ver=${5:-$(version "$2")};printf '%s' "select public.boss_games_mutate(md5('boss-phase5f-race-request:$request')::uuid,jsonb_build_object('operation','$op','input',jsonb_build_object('game_id','$(game_id "$label")','expected_version',$ver)||case when '$op' like 'diamond.%'then jsonb_build_object('sport_key','baseball')else '{}'::jsonb end||'$extra'::jsonb));"; }
profile(){ local label=$1 request=$2 gv=${3:-$(version "$1")};printf '%s' "select public.boss_games_mutate(md5('boss-phase5f-race-request:$request')::uuid,jsonb_build_object('operation','tracking.profile.set','input',jsonb_build_object('sport_key','baseball','scope_type','game','organization_id','$(uuid org)','game_id','$(game_id "$label")','side','opponent','expected_game_version',$gv,'expected_profile_version',1,'preset','score_only','reason','Synthetic Diamond race profile')));"; }
roster(){ local label=$1 sd=$2 n=$3 person;if [[ "$n" == 1 ]];then person=$(uuid "$(if [[ "$sd" == primary ]];then printf child1;else printf child2;fi)");else person=$("${psql_cmd[@]}" --command "select md5('boss-phase5f-race-roster:$sd-player-$n')::uuid");fi;"${psql_cmd[@]}" --command "select r.id from public.game_roster_snapshots r join public.games g on g.id=r.game_id and g.roster_revision=r.revision where g.id='$(game_id "$label")'and r.person_id='$person'"; }
admin=$(auth admin);scorer=$(auth scorer)
ball='{"payload":{"kind":"pitch","outcome":"ball"}}'
inplay='{"payload":{"kind":"pitch","outcome":"in_play"}}'
hit='{"payload":{"kind":"play","result":"single","moves":[{"from":0,"to":1,"out":false,"cause":"hit","force":false,"batter_before_first":false}]}}'
out='{"payload":{"kind":"play","result":"other_out","moves":[{"from":0,"to":null,"out":true,"cause":"advance_on_play","force":false,"batter_before_first":true}]}}'
v=$(version pitch)
race simultaneous_pitch "$admin$(command diamond.pitch.add pitch "$ball" pitch-one "$v")" "$admin$(command diamond.pitch.add pitch "$ball" pitch-two "$v")" PT409
assert_sql 'one accepted pitch and ball' "select state->'pa'->>'pitches'='1'and state->'pa'->>'balls'='1'from public.game_diamond_states where game_id='$(game_id pitch)'"
v=$(version pitchpa)
race pitch_vs_pa "$admin$(command diamond.pitch.add pitchpa "$inplay" pitchpa-one "$v")" "$admin$(command diamond.play.add pitchpa "$hit" pitchpa-two "$v")" PT409
v=$(version pa)
race simultaneous_pa "$admin$(command diamond.play.add pa "$hit" pa-one "$v")" "$admin$(command diamond.play.add pa "$hit" pa-two "$v")" PT409
assert_sql 'one PA terminal and one hit' "select stats->>'pa'='1'and stats->>'hits'='1'from boss_private.diamond_totals('$(game_id pa)')where side='primary'and roster_id is null"
advance='{"payload":{"kind":"advance","moves":[{"from":1,"to":2,"out":false,"cause":"stolen_base","force":false,"batter_before_first":false}]}}'
double='{"payload":{"kind":"play","result":"double","moves":[{"from":1,"to":3,"out":false,"cause":"hit","force":false,"batter_before_first":false},{"from":0,"to":2,"out":false,"cause":"hit","force":false,"batter_before_first":false}]}}'
v=$(version runner)
race pa_vs_runner "$admin$(command diamond.play.add runner "$double" runner-one "$v")" "$admin$(command diamond.runner.advance runner "$advance" runner-two "$v")" PT409
v=$(version third)
race third_out_transition "$admin$(command diamond.play.add third "$out" third-one "$v")" "$admin$(command diamond.half.start third '{"payload":{"kind":"half_start"}}' third-two "$v")" PT409
assert_sql 'third out closes exactly once' "select state->>'outs'='3'and state->>'status'='half_complete'and jsonb_array_length(state->'completed_halves')=1 from public.game_diamond_states where game_id='$(game_id third)'"
v=$(version scorefinal)
race play_vs_final "$admin$(command diamond.play.add scorefinal "$out" scorefinal-one "$v")" "$admin$(command game.finalize scorefinal '{}' scorefinal-two "$v")" PT409
v=$(version final)
race final_vs_late_play "$admin$(command game.finalize final '{}' final-one "$v")" "$admin$(command diamond.play.add final "$hit" final-two "$v")" PT409
assert_sql 'one immutable final epoch and coverage pair' "select(select count(*)=1 from public.game_diamond_finalizations where game_id='$(game_id final)')and(select count(*)=2 from public.game_finalization_tracking_seals where game_id='$(game_id final)')"
pitcher="{\"payload\":{\"kind\":\"pitcher_change\",\"side\":\"opponent\",\"pitcher\":\"$(roster pitcher opponent 3)\",\"key\":\"$(uuid pitcher-appearance)\"}}"
v=$(version pitcher)
race pitcher_vs_new_pitch "$admin$(command diamond.pitcher.change pitcher "$pitcher" pitcher-one "$v")" "$admin$(command diamond.pitch.add pitcher "$ball" pitcher-two "$v")" PT409
assert_sql 'pitcher boundary appends no orphan pitch' "select not exists(select 1 from public.game_diamond_events where game_id='$(game_id pitcher)'and event_type='pitch')"
sub="{\"payload\":{\"kind\":\"substitution\",\"side\":\"primary\",\"out_roster_id\":\"$(roster sub primary 1)\",\"in_roster_id\":\"$(roster sub primary 5)\",\"mode\":\"offensive\"}}"
v=$(version sub)
race substitution_collision "$admin$(command diamond.substitute sub "$sub" sub-one "$v")" "$admin$(command diamond.substitute sub "$sub" sub-two "$v")" PT409
assert_sql 'one accepted substitution' "select count(*)=1 from public.game_diamond_events where game_id='$(game_id sub)'and event_type='substitution'"
target=$("${psql_cmd[@]}" --command "select id from public.game_diamond_events where game_id='$(game_id correction)'and event_type='play'order by sequence limit 1")
correction="{\"event_id\":\"$target\",\"reason\":\"Synthetic correction\",\"payload\":{\"kind\":\"play\",\"result\":\"double\",\"pitch_gap\":true,\"moves\":[{\"from\":0,\"to\":2,\"out\":false,\"cause\":\"hit\",\"force\":false,\"batter_before_first\":false}]}}"
v=$(version correction)
race correction_vs_play "$admin$(command diamond.event.correct correction "$correction" correction-one "$v")" "$admin$(command diamond.play.add correction "$hit" correction-two "$v")" PT409
assert_sql 'correction retains original evidence' "select count(*)=2 from public.game_diamond_events where game_id='$(game_id correction)'and event_type='play'"
cmd=$(command diamond.pitch.add duplicate "$ball" duplicate)
race duplicate_pitch_receipt "$admin$cmd" "$admin$cmd" success
assert_sql 'exactly one pitch and receipt on retry' "select(select count(*)=1 from public.game_diamond_events where game_id='$(game_id duplicate)'and event_type='pitch')and(select count(*)=1 from boss_private.game_operation_receipts where request_id=md5('boss-phase5f-race-request:duplicate')::uuid)"
v=$(version profile)
race tracking_profile_vs_pitch "$admin$(profile profile profile-one "$v")" "$admin$(command diamond.pitch.add profile "$ball" profile-two "$v")" PT403
assignment=$("${psql_cmd[@]}" --command "select id from public.game_operator_assignments where game_id='$(game_id authority)'and person_id='$(uuid scorer)'and status='active'")
v=$(version authority)
race operator_revocation "$admin$(command game.operator.end authority "{\"assignment_id\":\"$assignment\"}" revoke "$v")" "$scorer$(command diamond.play.add authority "$hit" revoke-two "$v")" PT403
"${psql_cmd[@]}" --command "update public.game_operator_assignments set status='active',ends_at=clock_timestamp()+interval '1 hour'where id='$assignment'" >"$race_dir/phase5f-restore.out"
event_lock="select 1 from public.events where id='$(uuid event-ff-authority)'for update;"
race operator_expiry "$event_lock update public.game_operator_assignments set ends_at=clock_timestamp()+interval '0.25 seconds'where id='$assignment';" "$scorer$(command diamond.play.add authority "$hit" expiry "$v")" PT403 0.5
module_version=$("${psql_cmd[@]}" --command "select om.version from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id='$(uuid org)'and m.key='sports'")
feature="select public.boss_games_mutate(md5('boss-phase5f-race-request:feature')::uuid,jsonb_build_object('operation','games.configure','input',jsonb_build_object('organization_id','$(uuid org)','expected_version',$module_version,'configuration',jsonb_build_object('baseball_live_scoring',false))));"
v=$(version pitch)
race feature_disable "$admin$feature" "$admin$(command diamond.pitch.add pitch "$ball" disabled "$v")" PT403
assert_sql 'disabled contender added no second pitch' "select count(*)=1 from public.game_diamond_events where game_id='$(game_id pitch)'and event_type='pitch'"
printf 'Phase5F Diamond concurrency assertions passed: %s\n' "$race_count"
