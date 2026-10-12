import assert from "node:assert/strict";
import test from "node:test";
import { parseFootballCommand, projectFootballField, projectFootballTotals } from "../src/lib/football/input";
import { parseGameCommand } from "../src/lib/games/input";
import { footballOperations } from "../src/lib/football/contracts";
import type { GameCommand } from "../src/lib/games/contracts";
import { GameIntent } from "../src/lib/games/intent";
import { FootballIntent } from "../src/lib/football/intent";
import { footballData, footballRaw, footballGameRaw, footballFeatures, field, zeroStats, gameId, athleteId, receiverId, defenderId, otherAthleteId, playId } from "./football-fixture";
const base = { game_id: gameId, expected_version: 10 };
const command = (operation = "football.play.add", extra: Record<string, unknown> = {}) => ({ operation, input: { ...base, play_type: "rush", side: "primary", yards: -3, roster_id: athleteId, ...extra } });
test("Football commands share the signed game route and reject arbitrary authority, engine or raw-state fields", () => {
  assert.ok(parseGameCommand(command()));
  for (const key of ["organization_id", "team_id", "person_id", "operator_id", "actor", "field_state", "stats", "engine_version", "clock_anchor", "score"]) assert.equal(parseGameCommand(command("football.play.add", { [key]: gameId })), null, key);
  assert.equal(parseFootballCommand({ ...command(), token: "SYNTHETIC_DISALLOWED" }), null);
  assert.equal(parseGameCommand(command("football.stat.set")), null);
  assert.equal(footballOperations.includes("football.play.add"), true);
});
test("Football validates signed yardage, unique participant fields and whole-play placement tuples", () => {
  for (const yards of [-100, -3, 0, 100]) assert.ok(parseFootballCommand(command("football.play.add", { yards })));
  for (const yards of [-101, 101, 1.5, "12", null]) assert.equal(parseFootballCommand(command("football.play.add", { yards })), null);
  assert.ok(parseFootballCommand(command("football.play.add", { tackler_roster_id: receiverId, assisting_roster_ids: [defenderId] })));
  for (const assisting of [[defenderId, defenderId], [defenderId, athleteId, receiverId, otherAthleteId, playId], ["invalid"]]) assert.equal(parseFootballCommand(command("football.play.add", { assisting_roster_ids: assisting })), null);
  assert.equal(parseFootballCommand(command("football.play.add", { play_type: "kickoff", result_side: "opponent" })), null);
  assert.ok(parseFootballCommand({ operation: "football.play.add", input: { ...base, play_type: "kickoff", side: "primary", result_side: "opponent", result_ball_spot: 20, result_down: 1, result_distance: 10 } }));
  for (const input of [{ result_down: 5 }, { recovery_side: "unrelated" }, { roster_id: "forged" }, { made: "true" }, { penalty_status: "invented" }]) assert.equal(parseFootballCommand(command("football.play.add", input)), null);
});
test("Football configuration requires explicit finite competition policies and coherent overtime", () => {
  const input = { ...base, quarter_seconds: 720, overtime_format: "none", overtime_seconds: 300, max_overtime_periods: 0, play_clock_seconds: null, lineup_size: 11, enforce_lineup: false, kneel_counts_as_rush: false };
  assert.ok(parseFootballCommand({ operation: "football.configure", input }));
  for (const extra of [{ regulation_periods: 4 }, { lineup_size: 12 }, { quarter_seconds: 59 }, { overtime_format: "universal" }, { max_overtime_periods: 1 }, { play_clock_seconds: 4 }, { kneel_counts_as_rush: "false" }]) assert.equal(parseFootballCommand({ operation: "football.configure", input: { ...input, ...extra } }), null);
  assert.ok(parseFootballCommand({ operation: "football.configure", input: { ...input, overtime_format: "possession", max_overtime_periods: 2 } }));
});
test("Football replacement/reversal require original event and nonempty reviewed reason", () => {
  assert.ok(parseFootballCommand(command("football.play.correct", { event_id: playId, reason: "Controlled correction" })));
  for (const extra of [{}, { event_id: playId }, { event_id: playId, reason: " " }, { event_id: "wrong", reason: "Controlled" }]) assert.equal(parseFootballCommand(command("football.play.correct", extra)), null);
  assert.ok(parseFootballCommand({ operation: "football.play.reverse", input: { ...base, event_id: playId, reason: "Controlled reversal" } }));
  assert.equal(parseFootballCommand({ operation: "football.play.reverse", input: { ...base, event_id: playId, reason: "Controlled", yards: 2 } }), null);
});
test("Football type-specific meaning rejects irrelevant yards, wrong fumble base roles and duplicate tackle credit", () => {
  const play = (play_type: string, payload: Record<string, unknown>) => ({ operation: "football.play.add", input: { ...base, side: "primary", play_type, ...payload } });
  for (const [type, payload] of [["touchdown", { yards: 6 }], ["pass_incomplete", { yards: 2 }], ["spike", { yards: -2 }], ["sack", { yards: 0 }], ["kneel", { yards: 1 }], ["rush", { yards: 3, pass_defender_roster_id: defenderId }], ["fumble", { base_play_type: "rush", yards: 2, recovery_side: "primary", return_yards: 0, receiver_roster_id: receiverId }], ["rush", { yards: 3, tackler_roster_id: defenderId, assisting_roster_ids: [defenderId] }]] as const) assert.equal(parseFootballCommand(play(type, payload)), null, type);
  assert.ok(parseFootballCommand(play("pass_incomplete", { yards: 0, receiver_roster_id: receiverId })));
  assert.ok(parseFootballCommand(play("two_point", { made: true, receiver_roster_id: receiverId, yards: 2 })));
  assert.ok(parseFootballCommand(play("fumble", { base_play_type: "none", yards: 0, recovery_side: "opponent", return_yards: 2 })));
});
test("Football rejects contradictory touchback, confirmed penalty down and sack tackle outcomes", () => {
  const play = (play_type: string, payload: Record<string, unknown>) => ({ operation: "football.play.add", input: { ...base, side: "primary", play_type, ...payload } });
  const placement = { result_side: "primary", result_ball_spot: 25, result_down: 1, result_distance: 10 };
  assert.equal(parseFootballCommand(play("kickoff_return", { ...placement, return_yards: 2, touchback: true })), null);
  assert.equal(parseFootballCommand(play("kickoff_return", { ...placement, return_yards: 0, touchback: true, touchdown: true })), null);
  assert.equal(parseFootballCommand(play("penalty", { ...placement, result_down: 2, penalty_status: "accepted", penalty_yards: 10, automatic_first_down: true })), null);
  assert.equal(parseFootballCommand(play("penalty", { ...placement, penalty_status: "accepted", penalty_yards: 10, automatic_first_down: true, loss_of_down: true })), null);
  assert.equal(parseFootballCommand(play("fumble", { base_play_type: "sack", yards: -3, recovery_side: "primary", return_yards: 0, defender_roster_id: defenderId, tackler_roster_id: receiverId })), null);
  assert.ok(parseFootballCommand(play("penalty", { ...placement, penalty_status: "accepted", penalty_yards: 10, automatic_first_down: true })));
});
test("Football projection masks every payload identity independently and drops private audit material", () => {
  const state = footballData().games[0].football; assert.ok(state?.configured);
  assert.equal(state.plays[0].payload.defender_roster_id, undefined);
  assert.deepEqual(state.plays[0].payload.assisting_roster_ids, [defenderId]);
  assert.equal(state.plays[0].payload.roster_id, athleteId); assert.equal(state.plays[0].payload.receiver_roster_id, receiverId);
  assert.doesNotMatch(JSON.stringify(state), /OMIT_|actor_person_id|absence_reason|request_id|person_id/);
  const family = footballData({}, true).games[0].football; assert.ok(family?.configured);
  assert.deepEqual(family.entry_roster, []); assert.deepEqual(family.entry_plays, []); assert.deepEqual(family.final_epochs, []);
  assert.deepEqual(family.players.map(row => row.roster_id), [athleteId]);
  assert.equal(family.plays[0].payload.receiver_roster_id, undefined); assert.deepEqual(family.plays[0].payload.assisting_roster_ids, []);
  assert.deepEqual(family.capabilities, { configure: false, operate: false, correct: false, stats: true, lineups: false });
});
test("configured Football remains engine-owned when live feature is disabled and PBP-off strips injected drives", () => {
  const data = footballData({ features: { ...footballFeatures, football_live_scoring: false } }), game = data.games[0]; assert.equal(game.engine_locked, true); assert.ok(game.football?.configured); assert.equal(game.football.capabilities.operate, false); assert.equal(game.football.capabilities.stats, false);
  const off = footballData({ features: { ...footballFeatures, football_play_by_play: false } }).games[0].football; assert.ok(off?.configured); assert.deepEqual(off.plays, []); assert.deepEqual(off.drives, []); assert.equal(off.entry_plays.length, 1);
  const invalid = footballData({ games: [{ ...footballGameRaw, football: { ...footballRaw, field_state: { ...field, line_to_gain: 99 } } }] }).games[0]; assert.equal(invalid.football, null); assert.equal(invalid.engine_locked, true);
});
test("Football projection validates field phase, coherent goal-to-go and format clock boundaries", () => {
  assert.ok(projectFootballField(field));
  for (const extra of [{ line_to_gain: 51 }, { goal_to_go: true }, { phase: "try" }, { scoring_side: "primary" }, { phase: "unknown" }, { ball_spot: 101 }, { ball_spot: 95, distance: 10, line_to_gain: 100, goal_to_go: true }, { down: 0 }]) assert.equal(projectFootballField({ ...field, ...extra }), null);
  assert.ok(projectFootballField({ ...field, phase: "try", scoring_side: "primary" }));
  for (const extra of [{ max_overtime_periods: 1 }, { period_number: 5 }, { clock_ms: 720001 }, { engine_version: "football-v2" }]) assert.equal(footballData({ games: [{ ...footballGameRaw, football: { ...footballRaw, ...extra } }] }).games[0].football, null);
});
test("Football statistics preserve signed net yardage and unavailable longest field goal without arbitrary fields", () => {
  const totals = projectFootballTotals({ ...zeroStats, rushing_yards: -4, net_passing_yards: -5, total_offensive_yards: -9, private_reason: "OMIT_PRIVATE" }); assert.ok(totals); assert.equal(totals.rushing_yards, -4); assert.equal(totals.long_field_goal, null); assert.equal("private_reason" in totals, false);
  for (const extra of [{ passing_attempts: -1 }, { passing_yards: 1.5 }, { long_field_goal: -1 }, { receiving_yards: Infinity }]) assert.equal(projectFootballTotals({ ...zeroStats, ...extra }), null);
});
const rush: GameCommand = { operation: "football.play.add", input: { ...base, play_type: "rush", side: "primary", yards: 3, roster_id: athleteId } };
const saved = (version = 11, game_id = gameId) => new Response(JSON.stringify({ ok: true, result: { game_id, version, replayed: false, message: "Saved." } }), { status: 200 });
test("Football shared intent serializes double taps and waits for the acknowledged canonical version", async () => {
  const intent = new FootballIntent(); let finish!: (response: Response) => void, calls = 0;
  const first = intent.execute(rush, async () => { calls++; return new Promise(resolve => { finish = resolve; }); }); assert.equal((await intent.execute(rush, async () => saved())).kind, "busy"); assert.equal(calls, 1); finish(saved()); assert.equal((await first).kind, "saved"); assert.equal(intent.waitingFor(10), true);
  assert.equal((await intent.execute(rush, async () => saved())).kind, "refresh");
  assert.equal((await new FootballIntent().execute({ operation: "soccer.clock.stop", input: base })).kind, "invalid");
});
test("lost committed Football outcomes replay the same immutable request after refresh before any new sport mutation", async () => {
  const commands: GameCommand[] = [rush, { operation: "football.play.correct", input: { ...rush.input, event_id: playId, reason: "Controlled correction" } }, { operation: "football.play.reverse", input: { ...base, event_id: playId, reason: "Controlled reversal" } }, { operation: "football.substitute", input: { ...base, side: "primary", out_roster_id: athleteId, in_roster_id: receiverId } }, { operation: "football.clock.stop", input: base }];
  for (const command of commands) {
    let serial = 850, accepted = 0; const intent = new GameIntent(() => `00000000-0000-4000-8000-${String(serial++).padStart(12, "0")}`), receipts = new Set<string>(), requests: string[] = [];
    const transport = async (_url: RequestInfo | URL, init?: RequestInit) => { requests.push(String(init?.body)); assert.equal(init?.credentials, "same-origin"); assert.equal(init?.cache, "no-store"); const request = JSON.parse(requests.at(-1)!); if (!receipts.has(request.request_id)) { receipts.add(request.request_id); accepted++; } if (requests.length === 1) throw new Error("Controlled response loss"); return saved(10 + accepted); };
    assert.equal((await intent.execute(command, transport)).kind, "unknown"); const refreshed = { ...command, input: { ...command.input, expected_version: 11 } };
    assert.equal((await intent.execute(refreshed, transport)).kind, "unknown"); assert.equal((await intent.execute({ operation: "soccer.clock.stop", input: { ...base, expected_version: 11 } }, transport)).kind, "unknown"); assert.equal(requests.length, 1);
    assert.equal((await intent.retryUnconfirmed(transport)).kind, "saved"); assert.equal(requests[0], requests[1]); assert.equal(accepted, 1); assert.equal((await intent.execute(refreshed, transport)).kind, "saved"); assert.equal(accepted, 2); assert.notEqual(JSON.parse(requests[2]).request_id, JSON.parse(requests[1]).request_id);
  }
});
test("Football definitive authority denials clear retry and mismatched result identities remain unconfirmed", async () => {
  for (const status of [401, 403, 409, 422]) { const intent = new FootballIntent(); assert.equal((await intent.execute(rush, async () => { throw new Error("Controlled response loss"); })).kind, "unknown"); const outcome = await intent.retryUnconfirmed(async () => new Response(JSON.stringify({ secret: "OMIT_SERVER" }), { status })); assert.equal(intent.hasUnconfirmed(), false); assert.doesNotMatch(outcome.message, /OMIT_SERVER/); }
  assert.equal((await new FootballIntent().execute(rush, async () => saved(11, receiverId))).kind, "unknown");
});
