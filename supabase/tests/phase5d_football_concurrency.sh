#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Football races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase5D concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase5D race failure: %s\n' "$label" >&2
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
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase5d-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Football race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Football race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase5d-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase5d-$label-writer.out" 2>"$race_dir/phase5d-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase5d_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase5d-writer-ready */;" >&9
 await_state "boss_phase5d_${label}_writer" ready "$writer_pid" "$race_dir/phase5d-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase5d_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase5d-$label-contender.out" 2>"$race_dir/phase5d-$label-contender.err" & contender_pid=$!
 await_state "boss_phase5d_${label}_contender" waiting "$contender_pid" "$race_dir/phase5d-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase5d-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase5d-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase5d-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase5d-$label-contender.err";fail "$label expected $expected";fi
race_count=$((race_count+1))
}
# Actual canonical RPC in independent blocked connections. Preserve historical
# committed fixtures with a distinct fixed synthetic identity/slug namespace.
if [[ $(awk '$0=="\\ir ../phase5a/fixture.sql" {n++} END {print n+0}' "$test_dir/phase5d/fixture.sql") != 1 ]];then fail 'Football fixture must extend exactly one reviewed Game Center fixture';fi
sed -e 's/boss-phase5a-test:/boss-phase5d-race-base:/g' \
    -e 's/phase5a.example.invalid/phase5d-race.example.invalid/g' \
    -e 's/synthetic-phase5a-/synthetic-phase5d-race-/g' \
    "$test_dir/phase5a/fixture.sql" >"$race_dir/phase5d-race-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5d-test:/,"boss-phase5d-race-roster:");print}' \
    "$test_dir/phase5d/fixture.sql" >>"$race_dir/phase5d-race-fixture.sql"
cat >"$race_dir/phase5d-race-setup.sql" <<SQL
begin;
\ir '$race_dir/phase5d-race-fixture.sql'
set local role authenticated;select pg_temp.actor('admin');
do \$\$declare label text;i int;begin
 foreach label in array array['plays','score-final','turnover','correction','possession','down','authority','final-late','duplicate-rush','duplicate-pass','duplicate-td','duplicate-int','duplicate-fumble','duplicate-tackle','duplicate-kick','duplicate-return','duplicate-correction','duplicate-state']loop
  perform pg_temp.ff_create(label);
 end loop;
 perform pg_temp.ff_create('duplicate-sub','internal',true,true,6);
 perform pg_temp.ff_play('correction','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('correction','primary',2),'yards',1),'correction-source');
 perform pg_temp.ff_play('duplicate-correction','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('duplicate-correction','primary',2),'yards',1),'duplicate-correction-source');
 perform pg_temp.ff_play('duplicate-kick','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('duplicate-kick','primary',2),'yards',70,'touchdown',true),'kick-parent-td');
 perform pg_temp.ff_op('football.state.set','duplicate-return','{"side":"opponent","ball_spot":35,"down":1,"distance":10,"primary_direction":"increasing","reason":"Synthetic kicking side"}');
 foreach label in array array['score-final','final-late']loop
  for i in 1..3 loop perform pg_temp.ff_end(label);perform pg_temp.ff_op('football.period.start',label);end loop;
  perform pg_temp.ff_clock(label,0);
 end loop;
 perform pg_temp.game_op('game.operator.assign','authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',clock_timestamp()+interval '1 hour'));
end\$\$;
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase5d-race-setup.sql" >"$race_dir/phase5d-race-setup.out" 2>"$race_dir/phase5d-race-setup.err";then diagnostics setup "$race_dir/phase5d-race-setup.err";fail 'fixture setup';fi
uuid(){ "${psql_cmd[@]}" --command "select md5('boss-phase5d-race-base:$1')::uuid"; }
game_id(){ "${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase5d-race-base:event-ff-$1')::uuid"; }
version(){ "${psql_cmd[@]}" --command "select version from public.games where id='$(game_id "$1")'"; }
roster(){
 local label=$1 side=$2 n=$3 person
 if [[ "$n" == 1 ]];then if [[ "$side" == primary ]];then person=$(uuid child1);else person=$(uuid child2);fi
 else person=$("${psql_cmd[@]}" --command "select md5('boss-phase5d-race-roster:$side-player-$n')::uuid");fi
 "${psql_cmd[@]}" --command "select r.id from public.game_roster_snapshots r join public.games g on g.id=r.game_id and g.roster_revision=r.revision where g.id='$(game_id "$label")'and r.person_id='$person'"
}
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5d-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5d-race-base:session-$1')::uuid)::text,true);"; }
command(){
 local op=$1 label=$2 extra=$3 request=$4 ver=${5:-$(version "$2")}
 printf '%s' "select public.boss_games_mutate(md5('boss-phase5d-race-request:$request')::uuid,jsonb_build_object('operation','$op','input',jsonb_build_object('game_id','$(game_id "$label")','expected_version',$ver)||'$extra'::jsonb));"
}
rush(){ printf '{"play_type":"rush","side":"primary","roster_id":"%s","yards":%s}' "$(roster "$1" primary 2)" "$2"; }
state(){ printf '{"side":"%s","ball_spot":%s,"down":%s,"distance":%s,"primary_direction":"increasing","reason":"Synthetic confirmed collision state"}' "$1" "$2" "$3" "$4"; }
admin=$(auth admin);scorer=$(auth scorer)
# 1. Simultaneous plays; stale loser retry adds one next accepted fact.
v=$(version plays)
race simultaneous_plays "$admin$(command football.play.add plays "$(rush plays 2)" play-one "$v")" "$admin$(command football.play.add plays "$(rush plays 3)" play-two "$v")" PT409
assert_sql 'simultaneous plays retain one winner' "select count(*)=1 from public.game_football_events where game_id='$(game_id plays)'and event_type='rush'"
if ! "${psql_cmd[@]}" --command "begin;$admin$(command football.play.add plays "$(rush plays 3)" play-two)commit;" >"$race_dir/phase5d-play-retry.out" 2>"$race_dir/phase5d-play-retry.err";then diagnostics 'refreshed play retry' "$race_dir/phase5d-play-retry.err";fail 'refreshed loser retry';fi
assert_sql 'refreshed loser contributes once at next sequence' "select field_state->>'ball_spot'='35'and(select count(*)=2 from public.game_football_events where game_id=s.game_id and event_type='rush')from public.game_football_states s where game_id='$(game_id plays)'"
# 2. Accepted score wins over waiting finalization at the same version.
v=$(version score-final)
td="{\"play_type\":\"rush\",\"side\":\"primary\",\"roster_id\":\"$(roster score-final primary 2)\",\"yards\":70,\"touchdown\":true}"
race score_finalization "$admin$(command football.play.add score-final "$td" score-first "$v")" "$admin$(command game.finalize score-final '{}' score-final-second "$v")" PT409
assert_sql 'winning score has no partial losing seal' "select primary_score=6 and status='live'and not exists(select 1 from public.game_football_finalizations where game_id=g.id)from public.games g where id='$(game_id score-final)'"
# 3. Turnover changes possession before a waiting stale next play.
v=$(version turnover)
interception="{\"play_type\":\"interception\",\"side\":\"primary\",\"roster_id\":\"$(roster turnover primary 1)\",\"receiver_roster_id\":\"$(roster turnover primary 3)\",\"defender_roster_id\":\"$(roster turnover opponent 5)\",\"interception_spot\":40,\"return_yards\":5}"
race turnover_next_play "$admin$(command football.play.add turnover "$interception" turnover-one "$v")" "$admin$(command football.play.add turnover "$(rush turnover 1)" turnover-two "$v")" PT409
assert_sql 'turnover winner retains exact new receiving possession' "select field_state->>'possession_side'='opponent'and field_state->>'ball_spot'='65'and not exists(select 1 from public.game_football_events where game_id=s.game_id and event_type='rush')from public.game_football_states s where game_id='$(game_id turnover)'"
# 4. Append-only correction wins over a stale appended play.
target=$("${psql_cmd[@]}" --command "select id from public.game_football_events where game_id='$(game_id correction)'and event_type='rush'")
v=$(version correction)
correct="{\"event_id\":\"$target\",\"reason\":\"Synthetic winning yard correction\",\"play_type\":\"rush\",\"side\":\"primary\",\"roster_id\":\"$(roster correction primary 2)\",\"yards\":2}"
race correction_new_play "$admin$(command football.play.correct correction "$correct" correction-one "$v")" "$admin$(command football.play.add correction "$(rush correction 1)" correction-two "$v")" PT409
assert_sql 'correction retains immutable source plus one replacement' "select field_state->>'ball_spot'='32'and(select count(*)=2 from public.game_football_events where game_id=s.game_id and event_type='rush')and exists(select 1 from public.game_football_events where id='$target'and payload->>'yards'='1')from public.game_football_states s where game_id='$(game_id correction)'"
# 5/6. Possession and down/distance collisions serialize exact confirmed state.
v=$(version possession)
race possession_transition "$admin$(command football.state.set possession "$(state opponent 40 1 10)" possession-one "$v")" "$admin$(command football.state.set possession "$(state primary 60 1 10)" possession-two "$v")" PT409
assert_sql 'possession winner survives stale transition' "select field_state->>'possession_side'='opponent'and field_state->>'ball_spot'='40'from public.game_football_states where game_id='$(game_id possession)'"
v=$(version down)
race down_distance "$admin$(command football.state.set down "$(state primary 30 2 8)" down-one "$v")" "$admin$(command football.state.set down "$(state primary 30 3 7)" down-two "$v")" PT409
assert_sql 'down-distance winner is exact and bounded' "select field_state->>'down'='2'and field_state->>'distance'='8'and field_state->>'line_to_gain'='38'from public.game_football_states where game_id='$(game_id down)'"
# 7. Exact operator revocation rechecked after the contender's wait.
assignment=$("${psql_cmd[@]}" --command "select id from public.game_operator_assignments where game_id='$(game_id authority)'and person_id='$(uuid scorer)'and status='active'")
v=$(version authority)
race operator_revoke "$admin$(command game.operator.end authority "{\"assignment_id\":\"$assignment\"}" revoke-operator "$v")" "$scorer$(command football.play.add authority "$(rush authority 1)" revoked-play "$v")" PT403
assert_sql 'revoked waiting operator adds no play' "select not exists(select 1 from public.game_football_events where game_id='$(game_id authority)'and event_type='rush')"
"${psql_cmd[@]}" --command "update public.game_operator_assignments set status='active',ends_at=clock_timestamp()+interval '1 hour'where id='$assignment'" >"$race_dir/phase5d-authority-restore.out"
# 8. Current feature disable wins during an actual lock wait.
v=$(version authority)
module_version=$("${psql_cmd[@]}" --command "select om.version from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id='$(uuid org)'and m.key='sports'")
configure="select public.boss_games_mutate(md5('boss-phase5d-race-request:disable-feature')::uuid,jsonb_build_object('operation','games.configure','input',jsonb_build_object('organization_id','$(uuid org)','expected_version',$module_version,'configuration',jsonb_build_object('football_live_scoring',false))));"
race feature_disable "$admin$configure" "$scorer$(command football.play.add authority "$(rush authority 1)" feature-disabled-play "$v")" PT403
assert_sql 'disabled waiting feature adds no play' "select not exists(select 1 from public.game_football_events where game_id='$(game_id authority)'and event_type='rush')"
"${psql_cmd[@]}" --command "update public.organization_modules set configuration=configuration||'{\"football_live_scoring\":true}'where organization_id='$(uuid org)'and module_id=(select id from public.modules where key='sports')" >>"$race_dir/phase5d-authority-restore.out"
# 9. Finalization wins and the stale late play contributes nothing.
v=$(version final-late)
final_writer="$admin$(command football.clock.set final-late '{"clock_ms":0,"reason":"Synthetic final quarter"}' final-clock "$v")$(command football.period.end final-late '{}' final-end "$((v+1))")$(command game.finalize final-late '{}' final-seal "$((v+2))")"
race finalization_late_play "$final_writer" "$admin$(command football.play.add final-late "$(rush final-late 1)" final-late-play "$v")" PT409
assert_sql 'finalization wins before late play' "select status='final'and primary_score=0 and(select count(*)=1 from public.game_football_finalizations where game_id=g.id)and not exists(select 1 from public.game_football_events where game_id=g.id and request_id=md5('boss-phase5d-race-request:final-late-play')::uuid)from public.games g where id='$(game_id final-late)'"
# Extra revocation and natural-deadline cases use the same fixed eight seconds.
event_lock="select 1 from public.events where id='$(uuid event-ff-authority)'for update;"
v=$(version authority)
race role_revoke "$event_lock update public.role_assignments set status='inactive'where id='$(uuid role-scorer)';" "$scorer$(command football.play.add authority "$(rush authority 1)" role-revoked-play "$v")" PT403
"${psql_cmd[@]}" --command "update public.role_assignments set status='active'where id='$(uuid role-scorer)'" >>"$race_dir/phase5d-authority-restore.out"
race membership_revoke "$event_lock update public.team_memberships set status='inactive'where id='$(uuid membership-scorer)';" "$scorer$(command football.play.add authority "$(rush authority 1)" member-revoked-play "$v")" PT403
"${psql_cmd[@]}" --command "update public.team_memberships set status='active'where id='$(uuid membership-scorer)'" >>"$race_dir/phase5d-authority-restore.out"
race operator_expiry "$event_lock update public.game_operator_assignments set ends_at=clock_timestamp()+interval '0.25 seconds'where id='$assignment';" "$scorer$(command football.play.add authority "$(rush authority 1)" expired-play "$v")" PT403 0.5
"${psql_cmd[@]}" --command "update public.game_operator_assignments set ends_at=clock_timestamp()+interval '1 hour'where id='$assignment'" >>"$race_dir/phase5d-authority-restore.out"
race role_expiry "$event_lock update public.role_assignments set ends_at=clock_timestamp()+interval '0.25 seconds'where id='$(uuid role-scorer)';" "$scorer$(command football.play.add authority "$(rush authority 1)" role-expired-play "$v")" PT403 0.5
"${psql_cmd[@]}" --command "update public.role_assignments set ends_at=null where id='$(uuid role-scorer)'" >>"$race_dir/phase5d-authority-restore.out"
race session_expiry "$event_lock update auth.sessions set not_after=clock_timestamp()+interval '0.25 seconds'where id='$(uuid session-scorer)';" "$scorer$(command football.play.add authority "$(rush authority 1)" session-expired-play "$v")" PT401 0.5
"${psql_cmd[@]}" --command "update auth.sessions set not_after=null where id='$(uuid session-scorer)'" >>"$race_dir/phase5d-authority-restore.out"
# Genuine same-request races across all high-frequency accepted outcome families.
replay(){
 local label=$1 op=$2 extra=$3 request=$4 cmd
 cmd=$(command "$op" "$label" "$extra" "$request")
 race "$label" "$admin$cmd" "$admin$cmd" success
 assert_sql "$label has one event, ledger operation and receipt" "select(select count(*)=1 from public.game_football_events where game_id='$(game_id "$label")'and request_id=md5('boss-phase5d-race-request:$request')::uuid)and(select count(*)=1 from public.game_operations where game_id='$(game_id "$label")'and request_id=md5('boss-phase5d-race-request:$request')::uuid)and(select count(*)=1 from boss_private.game_operation_receipts where request_id=md5('boss-phase5d-race-request:$request')::uuid)"
}
replay duplicate-rush football.play.add "$(rush duplicate-rush 1)" rush-replay
pass="{\"play_type\":\"pass_complete\",\"side\":\"primary\",\"roster_id\":\"$(roster duplicate-pass primary 1)\",\"receiver_roster_id\":\"$(roster duplicate-pass primary 3)\",\"yards\":5}"
replay duplicate-pass football.play.add "$pass" pass-replay
assert_sql 'replayed complete pass is one five-yard completion and reception' "select stats->>'passing_completions'='1'and stats->>'passing_yards'='5'and stats->>'receiving_yards'='5'from boss_private.football_totals('$(game_id duplicate-pass)')where side='primary'and roster_id is null"
td="{\"play_type\":\"rush\",\"side\":\"primary\",\"roster_id\":\"$(roster duplicate-td primary 2)\",\"yards\":70,\"touchdown\":true}"
replay duplicate-td football.play.add "$td" td-replay
assert_sql 'replayed touchdown scores six once' "select primary_score=6 from public.games where id='$(game_id duplicate-td)'"
interception="{\"play_type\":\"interception\",\"side\":\"primary\",\"roster_id\":\"$(roster duplicate-int primary 1)\",\"defender_roster_id\":\"$(roster duplicate-int opponent 5)\",\"interception_spot\":40,\"return_yards\":5}"
replay duplicate-int football.play.add "$interception" int-replay
fumble="{\"play_type\":\"fumble\",\"side\":\"primary\",\"base_play_type\":\"rush\",\"roster_id\":\"$(roster duplicate-fumble primary 2)\",\"yards\":2,\"recovery_side\":\"opponent\",\"recovery_roster_id\":\"$(roster duplicate-fumble opponent 6)\",\"return_yards\":0}"
replay duplicate-fumble football.play.add "$fumble" fumble-replay
assert_sql 'replayed fumble is one lost fumble and one recovery' "select(stats->>'fumbles_lost'='1')from boss_private.football_totals('$(game_id duplicate-fumble)')where side='primary'and roster_id is null"
tackle="{\"play_type\":\"rush\",\"side\":\"primary\",\"roster_id\":\"$(roster duplicate-tackle primary 2)\",\"tackler_roster_id\":\"$(roster duplicate-tackle opponent 5)\",\"yards\":1}"
replay duplicate-tackle football.play.add "$tackle" tackle-replay
assert_sql 'replayed tackle gives one defender and team tackle' "select stats->>'tackles'='1'and stats->>'solo_tackles'='1'from boss_private.football_totals('$(game_id duplicate-tackle)')where side='opponent'and roster_id='$(roster duplicate-tackle opponent 5)'"
kick="{\"play_type\":\"extra_point\",\"side\":\"primary\",\"roster_id\":\"$(roster duplicate-kick primary 7)\",\"made\":true}"
replay duplicate-kick football.play.add "$kick" kick-replay
assert_sql 'replayed XP produces seven total points once' "select primary_score=7 from public.games where id='$(game_id duplicate-kick)'"
returned="{\"play_type\":\"kickoff_return\",\"side\":\"opponent\",\"roster_id\":\"$(roster duplicate-return opponent 7)\",\"returner_roster_id\":\"$(roster duplicate-return primary 4)\",\"return_yards\":20,\"result_side\":\"primary\",\"result_ball_spot\":30,\"result_down\":1,\"result_distance\":10}"
replay duplicate-return football.play.add "$returned" return-replay
assert_sql 'replayed return gives one KR and twenty yards' "select stats->>'kick_returns'='1'and stats->>'kick_return_yards'='20'from boss_private.football_totals('$(game_id duplicate-return)')where side='primary'and roster_id='$(roster duplicate-return primary 4)'"
target=$("${psql_cmd[@]}" --command "select id from public.game_football_events where game_id='$(game_id duplicate-correction)'and event_type='rush'")
replay duplicate-correction football.play.reverse "{\"event_id\":\"$target\",\"reason\":\"Synthetic duplicate reversal\"}" correction-replay
assert_sql 'replayed reversal retains original and one linked reversal' "select field_state->>'ball_spot'='30'and(select count(*)=1 from public.game_football_events where correction_of='$target')and exists(select 1 from public.game_football_events where id='$target')from public.game_football_states where game_id='$(game_id duplicate-correction)'"
sub="{\"side\":\"primary\",\"out_roster_id\":\"$(roster duplicate-sub primary 6)\",\"in_roster_id\":\"$(roster duplicate-sub primary 7)\"}"
replay duplicate-sub football.substitute "$sub" sub-replay
assert_sql 'replayed substitute retains six distinct slots' "select count(*)=6 and count(distinct roster_id)=6 and bool_or(roster_id='$(roster duplicate-sub primary 7)')and not bool_or(roster_id='$(roster duplicate-sub primary 6)')from public.game_football_lineups where game_id='$(game_id duplicate-sub)'and side='primary'"
replay duplicate-state football.state.set "$(state primary 40 1 10)" state-replay
assert_sql 'all Football race games retain one contiguous canonical ledger' "select bool_and(valid)from(select count(*)=max(o.sequence)and min(o.sequence)=1 and count(distinct o.version)=count(*)valid from public.games g join public.game_operations o on o.game_id=g.id where g.event_id in(select id from public.events where title like 'Synthetic Football %')and g.organization_id='$(uuid org)'group by g.id)x"
assert_sql 'Football race tenant restores feature/operator/role/member/session deadlines' "select(select(configuration->>'football_live_scoring')::boolean from public.organization_modules where organization_id='$(uuid org)'and module_id=(select id from public.modules where key='sports'))and(select status='active'and ends_at>clock_timestamp()from public.game_operator_assignments where id='$assignment')and(select status='active'and ends_at is null from public.role_assignments where id='$(uuid role-scorer)')and(select status='active'from public.team_memberships where id='$(uuid membership-scorer)')and(select not_after is null from auth.sessions where id='$(uuid session-scorer)')"
printf 'Phase5D Football concurrency assertions passed: %s\n' "$race_count"
