import assert from "node:assert/strict";
import test from "node:test";
import { parseDiamondCommand, projectDiamond } from "../src/lib/diamond/input";
import { initialDiamond, transitionDiamond } from "../src/lib/diamond/reducer";
import { defaultDiamondRules } from "../src/components/diamond/console";
import { resolveSelection } from "../src/lib/stat-tracking/profile";
const id = "10000000-0000-4000-8000-000000000001", other = "10000000-0000-4000-8000-000000000002";
const command = { operation: "diamond.play.add", input: { game_id: id, sport_key: "baseball", expected_version: 9, payload: { kind: "play", result: "single", moves: [{ from: 0, to: 1, out: false, cause: "hit", force: false, batter_before_first: false }] } } };
test("official Diamond requests reject forged scope, coverage and practice meaning", () => {
  assert.ok(parseDiamondCommand(command));
  for (const input of [{ ...command.input, team_id: other }, { ...command.input, sport_key: "football" }, { ...command.input, practice: true }, { ...command.input, expected_version: -1 }, { ...command.input, payload: { ...command.input.payload, pitch_gap: true } }, { ...command.input, payload: { ...command.input.payload, description: "hit" } }]) assert.equal(parseDiamondCommand({ ...command, input }), null);
  assert.ok(parseDiamondCommand({ operation: "diamond.event.correct", input: { ...command.input, event_id: other, reason: "Reviewed scorer decision", payload: { ...command.input.payload, pitch_gap: false } } }));
});
test("Diamond projection masks roster mappings, inherited runners and unrelated player stats", () => {
  const configuration = { ...defaultDiamondRules("softball", "opponent"), lineup_size: 1 };
  let state = initialDiamond(configuration);
  state = transitionDiamond(configuration, state, { kind: "lineup_set", side: "primary", order: [other], positions: {}, pitcher: null });
  state = transitionDiamond(configuration, state, { kind: "half_start" });
  state = transitionDiamond(configuration, state, { kind: "pa_start", key: id, batter: other, pitch_tracking: false });
  state = transitionDiamond(configuration, state, { kind: "play", result: "single", moves: command.input.payload.moves as import("../src/lib/diamond/contracts").DiamondMove[] });
  const raw = { configured: true, sport_key: "softball", engine_version: "diamond-v1", configuration, state, capabilities: { operate: true, correct: true, stats: true, lineups: true }, entry_roster: [{ id: other, side: "primary", display_name: "PRIVATE UNRELATED", active: true }], players: [{ roster_id: other, side: "primary", display_name: "PRIVATE UNRELATED", stats: {} }], tracking: { primary: { selection: resolveSelection("softball", "essential"), can_manage: true, profile_version: 9 } }, final_epochs: [{ epoch: 1, current_authoritative: true }], teams: [] };
  const family = projectDiamond(raw, { sport: "softball", family: true, visibleRosterIds: [], live: true, stats: true, lineups: true, canReviewEpochs: true });
  assert.ok(family); assert.equal(family.capabilities.operate, false); assert.equal(family.tracking.primary?.can_manage, false); assert.deepEqual(family.final_epochs, []); assert.doesNotMatch(JSON.stringify(family), /PRIVATE UNRELATED|10000000-0000-4000-8000-000000000002/);
  assert.equal(projectDiamond(raw, { sport: "baseball", family: false, visibleRosterIds: [], live: true, stats: true, lineups: true, canReviewEpochs: true }), null);
});
