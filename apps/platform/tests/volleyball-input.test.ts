import assert from "node:assert/strict";
import test from "node:test";
import { parseGameCommand } from "../src/lib/games/input";
import { buildVolleyballEntry } from "../src/lib/volleyball/entry";
import { parseVolleyballConfiguration, validVolleyballPayload, projectVolleyballStats } from "../src/lib/volleyball/input";
import { volleyballStatKeys } from "../src/lib/volleyball/contracts";
const game = "10000000-0000-4000-8000-000000000001", athlete = "10000000-0000-4000-8000-000000000002", other = "10000000-0000-4000-8000-000000000003";
const config = { best_of: 3, normal_target: 25, deciding_target: 15, win_by_two: true, court_size: 6, strict_rotation: true, enforce_lineup: true, allow_reentry: false, libero_enabled: true, libero_can_serve: false };
test("match format validates strict rotation, optional limits and finite keys", () => {
  assert.ok(parseVolleyballConfiguration(config));
  for (const changed of [{ best_of: 4 }, { court_size: 7 }, { enforce_lineup: false }, { score_cap: 14 }, { substitution_limit: 0 }, { unrelated: true }]) assert.equal(parseVolleyballConfiguration({ ...config, ...changed }), null);
});
test("both live entry orders use the identical canonical fact builder", () => {
  const actionFirst = buildVolleyballEntry(game, 7, "kill", "primary", athlete);
  const selectedPlayer = athlete, playerFirst = buildVolleyballEntry(game, 7, "kill", "primary", selectedPlayer);
  assert.deepEqual(actionFirst, playerFirst);
  assert.deepEqual(actionFirst, { operation: "volleyball.event.add", input: { game_id: game, expected_version: 7, event_type: "rally", side: "primary", payload: { outcome: "kill", roster_id: athlete } } });
  assert.deepEqual(buildVolleyballEntry(game, 7, "team_point", "primary", athlete)?.input.payload, { outcome: "team_point" });
});
test("assisted block needs distinct roster athletes; assist requires a fact reference", () => {
  assert.ok(validVolleyballPayload("rally", { outcome: "assisted_block", blocker_roster_ids: [athlete, other] }));
  assert.equal(validVolleyballPayload("rally", { outcome: "assisted_block", blocker_roster_ids: [athlete, athlete] }), false);
  assert.equal(validVolleyballPayload("assist", { roster_id: athlete }), false);
  assert.ok(validVolleyballPayload("assist", { roster_id: athlete, kill_event_id: game }));
  assert.equal(validVolleyballPayload("rally", { outcome: "team_point", roster_id: athlete }), false);
});
test("official Volleyball parser rejects arbitrary meaning and practice fields", () => {
  const canonical = buildVolleyballEntry(game, 7, "dig", "primary", athlete)!;
  assert.ok(parseGameCommand(canonical));
  assert.equal(parseGameCommand({ ...canonical, input: { ...canonical.input, practice: true } }), null);
  assert.equal(parseGameCommand({ ...canonical, input: { ...canonical.input, payload: { description: "score a point" } } }), null);
  assert.equal(parseGameCommand({ ...canonical, operation: "volleyball.future" }), null);
  assert.equal(parseGameCommand({ ...canonical, input: { ...canonical.input, side: "third_team" } }), null);
});
test("box projection rejects an untracked numeric zero and preserves partial values", () => {
  const stats = Object.fromEntries(volleyballStatKeys.map(k => [k, { recorded_value: k === "hitting_percentage" ? null : 0, coverage: "tracked", reason: "declared" }]));
  assert.ok(projectVolleyballStats(stats));
  stats.digs = { recorded_value: 0, coverage: "not_tracked", reason: "declared" };
  assert.equal(projectVolleyballStats(stats), null);
  stats.digs = { recorded_value: null, coverage: "not_tracked", reason: "declared" };
  stats.assists = { recorded_value: 2, coverage: "partially_tracked", reason: "declared" };
  assert.equal(projectVolleyballStats(stats)?.assists.recorded_value, 2);
});
