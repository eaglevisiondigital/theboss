#!/usr/bin/env bash
# Reuse real canonical sport oracles, add Phase 6A checks, roll everything back.
set -euo pipefail
umask 077
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ "${PGHOST:-}" == /tmp/boss-db-test.*/socket ]] || exit 1
work=$(mktemp -d /tmp/boss-phase6a-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
psql_cmd=("$PG_BINDIR/psql" -X -q --no-password --host "$PGHOST" --username postgres --dbname postgres -v ON_ERROR_STOP=1 -v VERBOSITY=terse)
for spec in 'phase5b_basketball.sql basketball bb_game basketball' 'phase5c_soccer.sql soccer sc_game oracle' 'phase5d_football.sql football ff_game oracle' 'phase5e_commands.sql volleyball ff_game oracle' 'phase5f_commands.sql baseball ff_game oracle';do
 read -r file sport helper label <<<"$spec"
 python3 - "$test_dir" "$file" "$helper" "$label" "$work/input.sql" <<'PY'
import sys,re
from pathlib import Path
root,file,helper,label,target=sys.argv[1:]
s=(Path(root)/file).read_text()
s=re.sub(r'^\\ir (.+)$',lambda m:"\\ir '"+str(Path(root)/m[1])+"'",s,flags=re.M)
s=re.sub(r"select pg_temp.game_op\('game.finalize','([^']+)'\);",lambda m:"select public.boss_stat_competition_classify(pg_temp."+helper+"('"+m[1]+"'),'official','Disposable synthetic source oracle',gen_random_uuid());"+m[0],s)
s=re.sub(r'^select count\(\*\).*passed_assertions.*$', '',s,flags=re.M)
s=re.sub(r'^rollback;$','',s,flags=re.M)
Path(target).write_text(s)
PY
 if [[ "$sport" == baseball ]];then
 cat >>"$work/input.sql" <<'SQL'
set local role authenticated;select pg_temp.actor('admin');
-- Complete the existing synthetic Softball oracle without inventing eligibility.
do $$declare half int;i int;begin
for half in 1..2 loop
for i in 1..3 loop perform pg_temp.dd_pa('softball','six-a-sb-'||half||'-'||i);perform pg_temp.dd_play('softball','other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end loop;
if half=1 then perform pg_temp.dd_op('diamond.half.start','softball','{"payload":{"kind":"half_start"}}');end if;end loop;
perform public.boss_stat_competition_classify(pg_temp.ff_game('softball'),'official','Disposable synthetic Softball source oracle',gen_random_uuid());
perform pg_temp.game_op('game.finalize','softball');end$$;
SQL
 fi
 cat >>"$work/input.sql" <<SQL
reset role;
truncate pg_temp.phase5a_assertions;
select boss_private.stat_refresh(id)from public.games where status='final';
select pg_temp.check('$sport current selectors clean','6A SOURCE',(select bool_and(gs.finalization_id=f.id and gs.generation=gs.refreshed_generation)from public.games g join public.stat_game_selections gs on gs.game_id=g.id join public.game_finalizations f on f.game_id=g.id and f.epoch=g.finalization_count where g.status='final'and g.sport_key='$sport'));
select pg_temp.check('$sport source rows retained exactly','6A SOURCE',(select count(*)>0 and bool_and(c.source_stat_id=s.source_stat_id and c.epoch=f.epoch and c.roster_revision=f.roster_revision and c.season_id is not distinct from g.season_id)from public.stat_game_contributions c join public.games g on g.id=c.game_id and g.status='final'and g.finalization_count=c.epoch join public.game_finalizations f on f.id=c.finalization_id join lateral boss_private.stat_sealed_rows(f.id)s on s.source_stat_id=c.source_stat_id where g.sport_key='$sport'));
select pg_temp.check('$sport component totals match current authoritative seals','6A SOURCE',not exists(select 1 from public.stat_game_contributions c join public.games g on g.id=c.game_id and g.status='final'and g.finalization_count=c.epoch join lateral boss_private.stat_sealed_rows(c.finalization_id)s on s.source_stat_id=c.source_stat_id left join public.game_finalization_tracking_seals t on t.finalization_id=c.finalization_id and t.side=c.side where g.sport_key='$sport'and(c.components-'scoring_for'-'scoring_against')is distinct from boss_private.stat_components(s.components,coalesce(t.coverage,'{}'),c.roster_id is not null)));
select pg_temp.check('$sport roster-only player is never fabricated GP','6A GP',not exists(select 1 from public.stat_game_contributions c join public.games g on g.id=c.game_id and g.finalization_count=c.epoch where g.sport_key='$sport'and c.roster_id is not null and c.participation->>'evidence'='insufficient'and(c.participation->>'confirmed')::boolean));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('$sport guardian career current after canonical corrections/transfer','6A PRIVACY',(public.boss_athlete_career_read(jsonb_build_object('person_id',pg_temp.f('child1'),'sport_key','$sport'))->>'is_current')::boolean);
select pg_temp.actor('household-only');
select pg_temp.denied('$sport household-only aggregate denied',format('select public.boss_athlete_career_read(%L::jsonb)',jsonb_build_object('person_id',pg_temp.f('child1'),'sport_key','$sport')),'PT403');
reset role;
SQL
 if [[ "$sport" == baseball ]];then
 cat >>"$work/input.sql" <<'SQL'
select pg_temp.check('Softball independently sealed official selection','6A SOURCE',(select gs.generation=gs.refreshed_generation and gs.finalization_id is not null from public.stat_game_selections gs join public.games g on g.id=gs.game_id where g.id=pg_temp.ff_game('softball')));
select pg_temp.check('Softball preserves reviewed 7-inning ERA provenance','6A ERA',(select bool_and(era_basis_innings=7)from public.stat_game_contributions where game_id=pg_temp.ff_game('softball')));
select pg_temp.check('Baseball preserves reviewed 9-inning ERA provenance','6A ERA',(select bool_and(era_basis_innings=9)from public.stat_game_contributions where game_id=pg_temp.ff_game('oracle')));
SQL
 fi
 cat >>"$work/input.sql" <<'SQL'
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
SQL
 if ! "${psql_cmd[@]}" --file "$work/input.sql" >"$work/output" 2>"$work/error";then
 awk '/ERROR:/{print;exit}' "$work/error" >&2;exit 1
 fi
 printf 'Phase6A sealed-source %s assertions: ' "$sport"
 awk '/passed_assertions/{show=1;next}show&&/^[[:space:]]*[0-9]+[[:space:]]*$/{gsub(/[[:space:]]/,"");print;exit}' "$work/output"
done
